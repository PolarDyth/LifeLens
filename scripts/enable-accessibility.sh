#!/bin/bash
# Helper script to grant accessibility permissions on macOS
# Run this script after installing the LifeLens desktop app

echo "LifeLens - Accessibility Permissions Helper"
echo "========================================="
echo ""

if [[ $(uname) != "Darwin" ]]; then
    echo "This script is for macOS only."
    exit 1
fi

echo "LifeLens needs accessibility permissions to track active windows."
echo ""
echo "To grant permissions:"
echo ""
echo "1. Open System Settings"
echo "2. Go to Privacy & Security → Accessibility"
echo "3. Find 'LifeLens' in the list"
echo "4. Toggle it ON"
echo ""
echo "Or click the button below to open System Settings directly:"
echo ""

# Try to open System Settings to Accessibility
osascript <<'EOF'
tell application "System Events"
    activate
    set preferences pane to pane id "com.apple.preference.security"
    reveal anchor "Privacy_Accessibility" of pane id "com.apple.preference.security"
end tell
EOF

echo ""
echo "✓ If System Settings opened, find 'LifeLens' and enable it."
echo ""
echo "After granting permissions, restart LifeLens."
