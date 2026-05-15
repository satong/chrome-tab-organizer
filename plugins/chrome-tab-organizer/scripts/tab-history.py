#!/usr/bin/env python3
"""
Chrome Tab History Tracker

Maintains a persistent log of every tab URL ever seen open in Chrome.
Called by chrome-organizer.sh before each cleanup run, and by /tab-update
on demand.

Storage: ~/.config/chrome-tab-organizer/history.tsv
Format:  first_seen<TAB>last_seen<TAB>url<TAB>title
"""

import os, sys, csv, re, glob
from datetime import datetime

CONFIG_DIR = os.path.expanduser("~/.config/chrome-tab-organizer")
HISTORY_FILE = os.path.join(CONFIG_DIR, "history.tsv")
SESSIONS_DIR = os.path.expanduser(
    "~/Library/Application Support/Google/Chrome/Default/Sessions/"
)


def load_history():
    history = {}
    if not os.path.exists(HISTORY_FILE):
        return history
    with open(HISTORY_FILE, "r", newline="") as f:
        reader = csv.reader(f, delimiter="\t")
        next(reader, None)
        for row in reader:
            if len(row) >= 4:
                history[row[2]] = {
                    "first_seen": row[0],
                    "last_seen": row[1],
                    "title": row[3],
                }
    return history


def save_history(history):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    entries = sorted(history.items(), key=lambda x: x[1]["last_seen"], reverse=True)
    with open(HISTORY_FILE, "w", newline="") as f:
        writer = csv.writer(f, delimiter="\t")
        writer.writerow(["first_seen", "last_seen", "url", "title"])
        for url, data in entries:
            writer.writerow([data["first_seen"], data["last_seen"], url, data["title"]])


def extract_tabs_from_session():
    tabs_files = glob.glob(os.path.join(SESSIONS_DIR, "Tabs_*"))
    if not tabs_files:
        return []

    newest = max(tabs_files, key=os.path.getmtime)
    with open(newest, "rb") as f:
        data = f.read()

    # Extract UTF-16LE titles with positions
    title_matches = []
    for m in re.finditer(rb"(?:[\x20-\x7e]\x00){8,200}", data):
        try:
            decoded = m.group().decode("utf-16-le").strip()
            if len(decoded) > 8:
                title_matches.append((m.start(), decoded))
        except Exception:
            pass

    # Extract URLs with positions
    url_positions = []
    for m in re.finditer(rb"https?://[a-zA-Z0-9._/\-?&=%#+@:~!,;()]+", data):
        try:
            url_positions.append((m.start(), m.group().decode("utf-8", errors="ignore")))
        except Exception:
            pass

    noise_titles = {
        "dynamicFrame", "chrome-extension", "Blink serialized",
        "textarea", "select-one", "No owner", "xp_id",
        "about:blank", "undefined", "viewport", "scroll",
        "opacity", "#root", "<!--",
    }
    noise_urls = {
        "gstatic.com", "googleapis.com", "googleusercontent.com",
        "chrome-extension://", "chrome://", "accounts.google.com",
        "apis.google.com", "docs.google.com/document/u/0",
        "docs.google.com/drivesharing", "docs.google.com/document/copy",
        "docs.google.com/presentation/copy", "www.google.com/url?q=",
        ".js", ".css", ".png", ".jpg", ".gif", ".svg", ".woff",
    }

    tabs = []
    seen_urls = set()

    for pos, title in title_matches:
        if any(x in title for x in noise_titles):
            continue
        if title.startswith("/") or title.startswith("http"):
            continue

        best_url = None
        best_dist = float("inf")
        for upos, uurl in url_positions:
            dist = abs(upos - pos)
            if dist < best_dist and dist < 2000:
                best_dist = dist
                best_url = uurl

        if best_url and best_url not in seen_urls and len(best_url) > 15:
            if any(s in best_url for s in noise_urls):
                continue
            seen_urls.add(best_url)
            tabs.append((best_url, title))

    for upos, uurl in url_positions:
        if uurl not in seen_urls and len(uurl) > 20:
            if any(s in uurl for s in noise_urls):
                continue
            clean = uurl.split("#")[0]
            if clean not in seen_urls:
                seen_urls.add(clean)
                tabs.append((clean, "(no title captured)"))

    return tabs


def search_history(query, limit=30):
    history = load_history()
    query_lower = query.lower()
    results = []
    for url, data in history.items():
        if query_lower in url.lower() or query_lower in data["title"].lower():
            results.append((url, data))
    results.sort(key=lambda x: x[1]["last_seen"], reverse=True)
    return results[:limit]


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "search":
        query = " ".join(sys.argv[2:])
        if not query:
            print("Usage: tab-history.py search <query>")
            sys.exit(1)
        results = search_history(query)
        if not results:
            print(f"No tabs found matching '{query}'")
            sys.exit(0)
        print(f"Found {len(results)} tabs matching '{query}':\n")
        for url, data in results:
            print(f"  {data['title']}")
            print(f"  {url}")
            print(f"  First seen: {data['first_seen']}  Last seen: {data['last_seen']}")
            print()
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "stats":
        history = load_history()
        print(f"Total unique URLs tracked: {len(history)}")
        if history:
            dates = [v["first_seen"][:10] for v in history.values()]
            print(f"Earliest record: {min(dates)}")
            print(f"Latest record: {max(dates)}")
        sys.exit(0)

    # Default: update history from current Chrome session
    print("Scanning Chrome session data...")
    tabs = extract_tabs_from_session()
    if not tabs:
        print("No tabs found in Chrome session data.")
        sys.exit(0)

    history = load_history()
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    new_count = 0
    updated_count = 0

    for url, title in tabs:
        if url in history:
            history[url]["last_seen"] = now
            if title != "(no title captured)" and history[url]["title"] == "(no title captured)":
                history[url]["title"] = title
            updated_count += 1
        else:
            history[url] = {"first_seen": now, "last_seen": now, "title": title}
            new_count += 1

    save_history(history)
    print(f"History updated: {new_count} new URLs, {updated_count} existing updated.")
    print(f"Total unique URLs tracked: {len(history)}")


if __name__ == "__main__":
    main()
