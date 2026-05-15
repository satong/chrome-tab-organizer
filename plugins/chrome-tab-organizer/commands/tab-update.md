---
displayName: 'Tab Update'
description: 'Manage Chrome tab clusters: scan for unmatched tabs, search tab history, add/remove clusters'
argument-hint: [optional: "search <query>", "history", "show", "add <name>", "remove <name>"]
---

# Chrome Tab Organizer - Update & Search

Manage the tab organizer config and search tab history.

## User Input

$ARGUMENTS

---

## Routing

Parse `$ARGUMENTS` and route to the appropriate section:

- **No arguments or "scan"**: Go to "Scan for Unmatched Tabs"
- **"search ..."**: Go to "Search Tab History"
- **"history"**: Go to "History Stats"
- **"show"**: Go to "Show Current Clusters"
- **"add ..."**: Go to "Add Cluster"
- **"remove ..."**: Go to "Remove Cluster"

---

## Show Current Clusters

Read `~/.config/chrome-tab-organizer/clusters.json` and present a summary:

| Cluster | Doc IDs | URL Patterns |
|---------|---------|-------------|
| [name] | [count] | [count] |

Also show the total and when the config was last modified.

---

## Scan for Unmatched Tabs

### Step 1: Read config

```bash
cat ~/.config/chrome-tab-organizer/clusters.json
```

### Step 2: Scan Chrome session

Extract current tabs from Chrome session files using the same technique as `/tab-setup` Step 2 (find newest `Tabs_*` file, extract URL-title pairs, filter noise).

Also update the tab history:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/tab-history.py
```

### Step 3: Match against clusters

For each tab URL, check if it matches any cluster's `doc_ids` or `url_patterns`. Separate into matched and unmatched.

### Step 4: Analyze unmatched tabs

For unmatched tabs:
- Extract Google Doc/Sheet/Slide IDs
- Extract domain patterns for non-Google URLs
- Use title keywords to suggest which existing cluster they likely belong to
- Group suggestions by cluster

### Step 5: Present findings

```
### Cluster Summary
| Cluster | Matched Tabs |
|---------|-------------|
| [name] | [count] |

### Unmatched Tabs ([count])

**Likely belongs to "[Cluster Name]":**
| Title | Doc ID / Pattern | Why |
|-------|-----------------|-----|
| [title] | `[id]` | Title mentions [keyword] |

**Possible new cluster: "[Suggested Name]":**
| Title | Doc ID / Pattern |
|-------|-----------------|
| [title] | `[id]` |

**One-off tabs (probably don't need a cluster):**
- [title] - [url]
```

### Step 6: Get approval and update

Ask which suggestions to apply. Do NOT modify the config until the user explicitly approves.

After approval, use the Edit tool to modify `~/.config/chrome-tab-organizer/clusters.json`:
- Add new doc_ids/url_patterns to existing clusters
- Create new cluster entries if requested

Show the diff of what changed.

---

## Search Tab History

### Step 1: Update history with latest tabs

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/tab-history.py
```

### Step 2: Search

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/tab-history.py search "<query>"
```

Where `<query>` is extracted from the user's arguments after "search".

### Step 3: Present results

Show results as a table:

| Title | URL | First Seen | Last Seen |
|-------|-----|------------|-----------|
| [title] | [url] | [date] | [date] |

If no results from keyword search, try reading the history file directly and use Claude's semantic understanding to find conceptual matches (e.g., "that doc about whether to build the feature natively" could match a tab titled "Build vs. Buy Analysis").

### Step 4: Reassurance message

Always end search results with:
> Your tab history has [N] URLs saved going back to [earliest date]. Every tab is automatically recorded 3x/day, so you can safely close tabs knowing you can find them here.

---

## History Stats

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/tab-history.py stats
```

Then read the history file and show:
- Total unique URLs tracked
- Date range (earliest to latest)
- 10 most recently added tabs
- 5 longest-lived tabs (largest gap between first_seen and last_seen)

---

## Add Cluster

If the user says `/tab-update add [Name]`:

1. Ask what doc IDs and URL patterns to include
2. Optionally scan current Chrome tabs and suggest matching ones
3. Add the new cluster to `~/.config/chrome-tab-organizer/clusters.json`
4. Show the updated config

---

## Remove Cluster

If the user says `/tab-update remove [Name]`:

1. Show the cluster's current contents (doc_ids, url_patterns)
2. Ask for confirmation
3. Remove from `~/.config/chrome-tab-organizer/clusters.json`
4. Note: tabs won't be deleted from Chrome, they'll just go to the "Inbox" window on next reorganization

---

## Important Notes

- NEVER run AppleScript or osascript from this command.
- Always get user approval before modifying the config.
- The config file is at `~/.config/chrome-tab-organizer/clusters.json`.
- The history file is at `~/.config/chrome-tab-organizer/history.tsv`.
- The tab-history.py script is at `${CLAUDE_PLUGIN_ROOT}/scripts/tab-history.py`.
