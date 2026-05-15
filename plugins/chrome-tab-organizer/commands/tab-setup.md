---
displayName: 'Tab Setup'
description: 'First-time Chrome tab organizer setup: AI-powered clustering, automation install, and tab history seeding'
argument-hint: ''
---

# Chrome Tab Organizer - First-Time Setup

Walk the user through initial setup: scan their Chrome tabs, create clusters using AI, configure the automation, and explain how to install the LaunchAgent.

## User Input

$ARGUMENTS

---

## Step 1: Prerequisites

Check that the environment supports the plugin:

```bash
uname -s  # Must be "Darwin"
ls /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome  # Must exist
```

If either fails, stop and explain:
- Not macOS: "This plugin only works on macOS (it uses AppleScript to control Chrome)."
- No Chrome: "Google Chrome must be installed at /Applications/Google Chrome.app."

Create the config directory:
```bash
mkdir -p ~/.config/chrome-tab-organizer
```

---

## Step 2: Scan Chrome Tabs

Find the most recent Chrome session file and extract all tab URL-title pairs.

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/tab-history.py
```

Then read the extracted data. Also do a deeper scan of the session file to get titles that the history script may have missed:

```python
import re, glob, os, json

sessions_dir = os.path.expanduser("~/Library/Application Support/Google/Chrome/Default/Sessions/")
tabs_files = glob.glob(os.path.join(sessions_dir, "Tabs_*"))
newest = max(tabs_files, key=os.path.getmtime)

with open(newest, 'rb') as f:
    data = f.read()

# Extract URL-title pairs (UTF-16LE titles near URLs)
# ... (use the same extraction logic as tab-history.py)
```

Filter out noise URLs:
- Chrome internal URLs, widget URLs, static assets
- Auth/login URLs, redirects
- `docs.google.com/document/u/0`, `/drivesharing/`, `/copy`

Present the count: "Found [N] tabs in Chrome."

---

## Step 3: AI Cluster Analysis

This is the core value step. Read ALL tab titles and URLs, then:

1. Group tabs by theme based on their titles. Look for:
   - Project names, product names, team names
   - Document types (PRDs, reviews, meeting notes, spreadsheets)
   - Domains (Figma = design, Google Sheets = data, Jira/Linear = project management)
   - Common keywords across multiple tabs

2. Propose 5-12 clusters. Each cluster should have:
   - A short, descriptive name (e.g., "Q3 Product Launch", "Hiring Pipeline", "Design Reviews")
   - The list of tabs that belong to it
   - The doc IDs and URL patterns that define membership

3. Create an "Inbox" for tabs that don't clearly belong anywhere.

4. Present the proposed clusters to the user in a clear format:

```
I analyzed your [N] tabs and found [M] natural clusters:

### 1. [Cluster Name] (X tabs)
- [Tab title 1]
- [Tab title 2]
- ...

### 2. [Cluster Name] (X tabs)
- [Tab title 1]
- ...

### Inbox (X tabs - no clear cluster)
- [Tab title 1]
- ...
```

5. Ask: "Would you like to adjust any clusters? You can rename, merge, split, or reassign tabs."

6. Iterate until the user is satisfied.

---

## Step 4: Junk Pattern Review

Load the default junk patterns:

```bash
cat ${CLAUDE_PLUGIN_ROOT}/templates/junk-patterns.json
```

Also scan the user's tabs for obvious junk that matches common patterns (SSO pages, expired Zoom links, login redirects). Show what would be auto-closed:

```
These tabs will be automatically closed by the organizer:
- [tab title] (matches: okta.com/sso)
- [tab title] (matches: zoom.us/j/)
- ...

The default junk patterns are: [list]
Want to add or remove any patterns?
```

---

## Step 5: Save Config

Build the clusters.json from the approved clusters:

```json
{
  "clusters": {
    "Cluster Name": {
      "doc_ids": ["abc123def456"],
      "url_patterns": ["figma.com/board/xyz"]
    }
  },
  "version": 1
}
```

For each tab in a cluster:
- If it's a Google Doc/Sheet/Slide, extract the document ID (the long alphanumeric string after `/d/` in the URL) and add to `doc_ids`
- For other URLs, extract a meaningful domain+path pattern and add to `url_patterns`
- Add a comment-style entry in a separate `_comments` field mapping doc IDs to titles for human readability

Write to `~/.config/chrome-tab-organizer/clusters.json`.

Also copy junk patterns (with any user modifications):
Write to `~/.config/chrome-tab-organizer/junk-patterns.json`.

---

## Step 6: Seed Tab History

Run the history tracker to record all current tabs:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/tab-history.py
```

Tell the user: "Recorded [N] tabs to your history. From now on, every tab you open will be tracked automatically. You can search your full tab history anytime with `/tab-update search <query>`."

---

## Step 7: Output Installation Instructions

Do NOT attempt to run the install script or osascript from within Claude Code. Instead, print clear instructions:

```
Setup complete! Your cluster config is saved.

To activate automatic tab organization, run these commands in Terminal.app (not here):

    bash [PLUGIN_ROOT]/scripts/install.sh

This will:
- Copy the organizer scripts to ~/.config/chrome-tab-organizer/scripts/
- Install a LaunchAgent that runs 3x/day (9:30 AM, 1:30 PM, 5:30 PM)
- Test Chrome automation permission (macOS will ask you to allow it)

After installation, your tabs will be automatically organized into these windows:
[list cluster names]

To update clusters later, use: /tab-update
To search your tab history: /tab-update search <query>
```

Replace `[PLUGIN_ROOT]` with the actual path from `${CLAUDE_PLUGIN_ROOT}`.

---

## Important Notes

- NEVER attempt to run AppleScript or osascript from within this command. The Automation permission model means it will fail from Claude Code's process context.
- ALWAYS present cluster proposals for user approval before saving. Never auto-save without confirmation.
- When extracting doc IDs, use the substring between `/d/` and the next `/` in Google Docs/Sheets/Slides URLs.
- Keep cluster names short (2-4 words). Users will see these as mental labels for their Chrome windows.
