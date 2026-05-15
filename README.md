# Chrome Tab Organizer

A Claude Code plugin that tames Chrome tab sprawl for knowledge workers.

Claude analyzes your open tabs, discovers your projects and workstreams, and creates a personalized configuration. A scheduled script then keeps your tabs automatically organized into one Chrome window per project, 3x per day. A persistent tab history records every URL you ever visit, so you can close tabs without fear of losing them.

## How it works

```
Claude (the brain)              Shell script (the muscle)
                     config
/tab-setup  ───────► clusters.json ◄──── chrome-organizer.sh
 "these 15 tabs          │               reads config, moves
  are about              │               tabs into the right
  Project Alpha"         │               windows 3x/day
                         │
/tab-update ──────►      │
 "add this new           │
  doc to the             │
  right cluster"         │
```

Claude writes the config. The script reads the config. Claude can't directly control Chrome windows (macOS permission model), so the script handles that from Terminal.

## Requirements

- **macOS** (uses AppleScript to control Chrome)
- **Google Chrome**
- **Claude Code** (CLI, desktop app, or IDE extension)
- **Python 3** (pre-installed on macOS)

## Installation

```bash
git clone https://github.com/satong/chrome-tab-organizer \
  ~/.claude/plugins/chrome-tab-organizer
```

Then in Claude Code:

```
/tab-setup
```

Claude will scan your tabs, propose clusters, and walk you through setup. At the end, it gives you a single command to run in Terminal to activate the automation.

## Commands

### `/tab-setup`

One-time initial setup. Claude:
1. Scans all your Chrome tabs
2. Reads every title, groups by theme
3. Proposes project-based clusters for your approval
4. Saves the config
5. Tells you how to install the automation

### `/tab-update`

Ongoing maintenance and search:

| Subcommand | What it does |
|------------|-------------|
| `/tab-update` | Scan for new tabs not matching any cluster, propose additions |
| `/tab-update search <query>` | Search your full tab history by keyword |
| `/tab-update show` | Display current cluster summary |
| `/tab-update history` | Tab history stats |
| `/tab-update add <name>` | Add a new cluster |
| `/tab-update remove <name>` | Remove a cluster |

## Tab History

Every tab URL and title is recorded with first-seen and last-seen timestamps. The history is updated 3x/day *before* any cleanup runs, so tabs are saved even if they get closed.

Search anytime:
```
/tab-update search quarterly planning
```

This is the "safety net" that lets you close tabs without anxiety.

## What gets auto-closed

The organizer automatically closes obviously disposable tabs:
- SSO/OAuth login pages (Okta, Microsoft, Auth0)
- Expired Zoom meeting links
- Google Doc copy/share dialogs
- URL redirects (Google, Facebook, Outlook SafeLinks)

You can customize the list in `~/.config/chrome-tab-organizer/junk-patterns.json`.

## How the automation works

The installer creates a macOS LaunchAgent that runs `chrome-organizer.sh` at 9:30 AM, 1:30 PM, and 5:30 PM. Each run:

1. Records all tabs to history (before any changes)
2. Closes junk tabs matching your patterns
3. Checks if tabs are well-organized (>80% in the right cluster windows)
4. If not, reorganizes: creates new windows per cluster, closes old windows by ID

The script only reorganizes when tabs are significantly scattered. If things are already tidy, it just closes junk and moves on.

## File locations

| File | Purpose |
|------|---------|
| `~/.config/chrome-tab-organizer/clusters.json` | Your cluster definitions |
| `~/.config/chrome-tab-organizer/junk-patterns.json` | Auto-close URL patterns |
| `~/.config/chrome-tab-organizer/history.tsv` | Persistent tab history |
| `~/.config/chrome-tab-organizer/scripts/` | Organizer and history scripts |
| `/tmp/chrome-tab-organizer.log` | Script execution log |

## Uninstall

```bash
bash ~/.claude/plugins/chrome-tab-organizer/scripts/uninstall.sh
```

## Limitations

- **macOS only.** AppleScript is the only reliable way to control Chrome windows programmatically. No Windows or Linux support.
- **Chrome only.** Firefox, Safari, and Arc are not supported.
- **Not real-time.** The automation runs 3x/day on a schedule, not instantly when you open a new tab.
- **Requires Terminal permission.** macOS must allow Terminal.app to control Chrome. You'll be prompted the first time.
- **Session file parsing is undocumented.** Chrome's binary session format could change with updates, potentially breaking tab scanning. The organizer script uses live AppleScript as a fallback.

## Privacy

All data stays on your machine. Tab URLs and titles are stored locally in `~/.config/chrome-tab-organizer/`. Nothing is uploaded, shared, or sent to any server. Tab data is passed to Claude only during `/tab-setup` and `/tab-update` commands, within your existing Claude Code session.

## License

MIT
