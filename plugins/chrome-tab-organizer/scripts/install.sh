#!/bin/bash
# install.sh - Install the Chrome Tab Organizer LaunchAgent
# Run from Terminal.app (NOT from Claude Code)

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${HOME}/.config/chrome-tab-organizer"
SCRIPT_DIR="${CONFIG_DIR}/scripts"
PLIST_NAME="com.$(whoami).chrome-tab-organizer"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"

echo "=== Chrome Tab Organizer Installer ==="
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This tool only works on macOS."
    exit 1
fi

# Check Chrome
if [[ ! -d "/Applications/Google Chrome.app" ]]; then
    echo "ERROR: Google Chrome not found at /Applications/Google Chrome.app"
    exit 1
fi

# Create config dir
mkdir -p "$CONFIG_DIR" "$SCRIPT_DIR"

# Copy scripts
cp "${PLUGIN_DIR}/scripts/chrome-organizer.sh" "$SCRIPT_DIR/"
cp "${PLUGIN_DIR}/scripts/tab-history.py" "$SCRIPT_DIR/"
chmod +x "${SCRIPT_DIR}/chrome-organizer.sh"

# Copy default junk patterns if not already configured
if [[ ! -f "${CONFIG_DIR}/junk-patterns.json" ]]; then
    cp "${PLUGIN_DIR}/templates/junk-patterns.json" "$CONFIG_DIR/"
    echo "Installed default junk patterns."
fi

# Check if clusters.json exists (should be created by /tab-setup)
if [[ ! -f "${CONFIG_DIR}/clusters.json" ]]; then
    echo ""
    echo "WARNING: No cluster config found."
    echo "Run /tab-setup in Claude Code first to generate your clusters."
    echo "The LaunchAgent will be installed but won't organize until clusters are configured."
    cp "${PLUGIN_DIR}/templates/clusters.json" "$CONFIG_DIR/"
fi

# Generate LaunchAgent plist from template
sed -e "s|__USERNAME__|$(whoami)|g" \
    -e "s|__SCRIPT_PATH__|${SCRIPT_DIR}/chrome-organizer.sh|g" \
    "${PLUGIN_DIR}/templates/launchagent.plist" > "$PLIST_PATH"

echo "Installed LaunchAgent at: $PLIST_PATH"

# Test Chrome automation permission
echo ""
echo "Testing Chrome automation permission..."
if osascript -e 'tell application "Google Chrome" to get version' &>/dev/null; then
    echo "Chrome automation permission: OK"
else
    echo ""
    echo "Chrome automation permission not granted yet."
    echo "macOS should show a dialog asking to allow Terminal to control Chrome."
    echo "Click 'OK' to grant permission, then re-run this script."
    echo ""
    echo "If no dialog appears, go to:"
    echo "  System Settings > Privacy & Security > Automation"
    echo "  Enable 'Google Chrome' under 'Terminal'"
    exit 1
fi

# Unload existing agent if present, then load new one
launchctl bootout "gui/$(id -u)/${PLIST_NAME}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"

echo ""
echo "=== Installation complete ==="
echo ""
echo "The organizer will run automatically at 9:30 AM, 1:30 PM, and 5:30 PM."
echo ""
echo "To test it now:"
echo "  bash ${SCRIPT_DIR}/chrome-organizer.sh"
echo ""
echo "To check logs:"
echo "  cat /tmp/chrome-tab-organizer.log"
echo ""
echo "To uninstall:"
echo "  bash ${PLUGIN_DIR}/scripts/uninstall.sh"
