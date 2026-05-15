#!/bin/bash
# chrome-organizer.sh - Automated Chrome tab cleanup and clustering
# Runs 3x/day via LaunchAgent. Also safe to run manually from Terminal.
#
# Reads config from: ~/.config/chrome-tab-organizer/clusters.json
# Records history to: ~/.config/chrome-tab-organizer/history.tsv

set -uo pipefail

CONFIG_DIR="${HOME}/.config/chrome-tab-organizer"
CLUSTERS_FILE="${CONFIG_DIR}/clusters.json"
JUNK_FILE="${CONFIG_DIR}/junk-patterns.json"
HISTORY_SCRIPT="$(dirname "$0")/tab-history.py"
LOG_FILE="/tmp/chrome-tab-organizer.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    echo "$msg"
}

# Keep log under 1000 lines
if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) -gt 1000 ]]; then
    tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

log "=== Chrome Tab Organizer starting ==="

# Check Chrome is running
if ! osascript -e 'tell application "Google Chrome" to get version' &>/dev/null; then
    log "Chrome not running or not accessible. Exiting."
    exit 0
fi

# Check config exists
if [[ ! -f "$CLUSTERS_FILE" ]]; then
    log "No cluster config found at $CLUSTERS_FILE. Run /tab-setup first."
    exit 1
fi

###############################################################################
# PHASE 0: Record tab history BEFORE any cleanup
###############################################################################
log "Phase 0: Recording tab history..."
if [[ -f "$HISTORY_SCRIPT" ]]; then
    python3 "$HISTORY_SCRIPT" >> "$LOG_FILE" 2>&1 || log "WARNING: Tab history update failed"
fi

###############################################################################
# PHASE 1: Close junk tabs
###############################################################################
log "Phase 1: Closing junk tabs..."

# Build junk patterns for AppleScript
JUNK_PATTERNS=""
if [[ -f "$JUNK_FILE" ]]; then
    JUNK_PATTERNS=$(python3 -c "
import json
with open('$JUNK_FILE') as f:
    data = json.load(f)
for p in data.get('patterns', []):
    print(p)
" 2>/dev/null)
fi

if [[ -n "$JUNK_PATTERNS" ]]; then
    # Convert to AppleScript list
    AS_LIST=$(echo "$JUNK_PATTERNS" | while read -r p; do printf '"%s", ' "$p"; done | sed 's/, $//')

    CLOSED=$(osascript -e "
    tell application \"Google Chrome\"
        set closePatterns to {${AS_LIST}}
        set closedCount to 0
        set winCount to count of windows
        repeat with i from winCount to 1 by -1
            set w to window i
            set tabCount to count of tabs of w
            repeat with j from tabCount to 1 by -1
                set tabUrl to URL of tab j of w
                set shouldClose to false
                repeat with p in closePatterns
                    if tabUrl contains (p as text) then
                        set shouldClose to true
                        exit repeat
                    end if
                end repeat
                if shouldClose and tabCount > 1 then
                    delete tab j of w
                    set tabCount to tabCount - 1
                    set closedCount to closedCount + 1
                end if
            end repeat
        end repeat
        return closedCount
    end tell
    " 2>/dev/null) || CLOSED="error"

    log "Closed $CLOSED junk tabs."
fi

###############################################################################
# PHASE 2: Collect all tabs
###############################################################################
log "Phase 2: Collecting tabs..."

osascript -e '
tell application "Google Chrome"
    set output to ""
    set winCount to count of windows
    repeat with i from 1 to winCount
        set w to window i
        set wid to id of w
        set tabCount to count of tabs of w
        repeat with j from 1 to tabCount
            set t to tab j of w
            set output to output & wid & "|" & j & "|" & (URL of t) & "|" & (title of t) & linefeed
        end repeat
    end repeat
    return output
end tell
' > /tmp/chrome_tab_dump.txt 2>/dev/null

TAB_COUNT=$(wc -l < /tmp/chrome_tab_dump.txt 2>/dev/null | tr -d ' ')
log "Found $TAB_COUNT tabs."

if [[ "$TAB_COUNT" -lt 3 ]]; then
    log "Too few tabs to organize. Exiting."
    rm -f /tmp/chrome_tab_dump.txt
    exit 0
fi

###############################################################################
# PHASE 3: Cluster analysis and reorganization
###############################################################################
log "Phase 3: Analyzing clusters..."

python3 << 'PYEOF'
import json, sys, os
from collections import Counter, defaultdict

config_dir = os.path.expanduser("~/.config/chrome-tab-organizer")
clusters_file = os.path.join(config_dir, "clusters.json")

with open(clusters_file) as f:
    config = json.load(f)

CLUSTERS = config.get("clusters", {})
if not CLUSTERS:
    print("No clusters configured. Run /tab-setup.", file=sys.stderr)
    sys.exit(0)

tabs = []
with open("/tmp/chrome_tab_dump.txt") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split("|", 3)
        if len(parts) == 4:
            tabs.append({
                "win_id": int(parts[0]),
                "tab_idx": int(parts[1]),
                "url": parts[2],
                "title": parts[3],
            })

if not tabs:
    sys.exit(0)

# Assign each tab to a cluster
for tab in tabs:
    tab["cluster"] = None
    for name, patterns in CLUSTERS.items():
        for pat in patterns.get("doc_ids", []):
            if pat in tab["url"]:
                tab["cluster"] = name
                break
        if tab["cluster"]:
            break
        for pat in patterns.get("url_patterns", []):
            if pat in tab["url"]:
                tab["cluster"] = name
                break
        if tab["cluster"]:
            break
    if not tab["cluster"]:
        tab["cluster"] = "Inbox"

# Check organization score
win_clusters = {}
for tab in tabs:
    win_clusters.setdefault(tab["win_id"], []).append(tab["cluster"])

win_dominant = {}
for wid, cl in win_clusters.items():
    win_dominant[wid] = Counter(cl).most_common(1)[0][0]

correct = sum(1 for tab in tabs if win_dominant[tab["win_id"]] == tab["cluster"])
total = len(tabs)
pct = (correct / total * 100) if total > 0 else 100

print(f"Organization: {pct:.0f}% ({correct}/{total})", file=sys.stderr)

if pct >= 80:
    print("SKIP", file=sys.stderr)
    sys.exit(0)

print(f"Reorganizing ({pct:.0f}% organized)...", file=sys.stderr)

# Deduplicate
seen = set()
unique = []
for tab in tabs:
    if tab["url"] not in seen:
        seen.add(tab["url"])
        unique.append(tab)

# Group by cluster
cluster_tabs = defaultdict(list)
for tab in unique:
    cluster_tabs[tab["cluster"]].append(tab)

# Generate AppleScript
lines = ['tell application "Google Chrome"']
lines.append('    set oldWindowIds to {}')
lines.append('    repeat with w in windows')
lines.append('        set end of oldWindowIds to id of w')
lines.append('    end repeat')
lines.append('')

cluster_order = sorted(cluster_tabs.keys(), key=lambda x: (x == "Inbox", x))
for name in cluster_order:
    ctabs = cluster_tabs[name]
    if not ctabs:
        continue
    first_url = ctabs[0]["url"].replace('"', '\\"')
    lines.append(f'    -- {name} ({len(ctabs)} tabs)')
    lines.append(f'    set newWin to make new window')
    lines.append(f'    set URL of active tab of newWin to "{first_url}"')
    for tab in ctabs[1:]:
        safe_url = tab["url"].replace('"', '\\"')
        lines.append(f'    make new tab at end of tabs of newWin with properties {{URL:"{safe_url}"}}')
    lines.append('')

lines.append('    -- Close original windows by saved ID')
lines.append('    repeat with oldId in oldWindowIds')
lines.append('        try')
lines.append('            close (first window whose id is oldId)')
lines.append('        end try')
lines.append('    end repeat')
lines.append('end tell')

with open("/tmp/chrome_reorg.scpt", "w") as f:
    f.write("\n".join(lines))

print(f"REORG: {len(cluster_order)} windows, {len(unique)} tabs", file=sys.stderr)
PYEOF

if [[ -f /tmp/chrome_reorg.scpt ]] && grep -q "set newWin" /tmp/chrome_reorg.scpt 2>/dev/null; then
    log "Reorganizing tabs into cluster windows..."
    osascript /tmp/chrome_reorg.scpt 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log "Reorganization complete."
    else
        log "ERROR: Reorganization failed."
    fi
    rm -f /tmp/chrome_reorg.scpt
else
    log "Tabs already well-organized. Skipping."
fi

rm -f /tmp/chrome_tab_dump.txt
log "=== Chrome Tab Organizer finished ==="
