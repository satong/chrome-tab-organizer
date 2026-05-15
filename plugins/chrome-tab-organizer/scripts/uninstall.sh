#!/bin/bash
# uninstall.sh - Remove the Chrome Tab Organizer LaunchAgent and config

set -uo pipefail

PLIST_NAME="com.$(whoami).chrome-tab-organizer"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"
CONFIG_DIR="${HOME}/.config/chrome-tab-organizer"

echo "=== Chrome Tab Organizer Uninstaller ==="
echo ""

# Unload LaunchAgent
if [[ -f "$PLIST_PATH" ]]; then
    launchctl bootout "gui/$(id -u)/${PLIST_NAME}" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "Removed LaunchAgent."
else
    echo "No LaunchAgent found."
fi

echo ""
read -p "Also remove config and tab history? (y/n): " CONFIRM

if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
    rm -rf "$CONFIG_DIR"
    echo "Removed config directory: $CONFIG_DIR"
else
    echo "Config preserved at: $CONFIG_DIR"
fi

rm -f /tmp/chrome-tab-organizer.log /tmp/chrome-tab-organizer-stdout.log /tmp/chrome-tab-organizer-stderr.log
echo ""
echo "Uninstall complete."
