#!/bin/bash
#
# Unlock PBL Zone — removes macOS quarantine so the app can open normally.
# Double-click this file after dragging "PBL Zone.app" to /Applications.
#

APP_NAME="PBL Zone"
APP_PATH="/Applications/${APP_NAME}.app"

echo ""
echo "  ⚠️   WARNING"
echo "  ────────────────────────────────────────────────────────"
echo "  This will remove macOS Gatekeeper protection from"
echo "  \"${APP_NAME}.app\". Only continue if you downloaded"
echo "  this app from the official release page:"
echo ""
echo "    https://github.com/NewEduAI/PBL-iOS/releases"
echo ""
echo "  If you got this from an untrusted source, press N to cancel."
echo "  ────────────────────────────────────────────────────────"
echo ""
read -r -p "  Continue? [y/N] " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo "  Cancelled."
    echo ""
    read -n 1 -s -r -p "  Press any key to close..."
    exit 0
fi

if [ ! -d "$APP_PATH" ]; then
    echo ""
    echo "  ❌  \"${APP_NAME}.app\" not found in /Applications."
    echo "     Please drag it to /Applications first, then run this again."
    echo ""
    read -n 1 -s -r -p "  Press any key to close..."
    exit 1
fi

echo ""
echo "  🔓  Unlocking \"${APP_NAME}\"..."
echo "     You may be asked for your password."
echo ""

osascript -e "do shell script \"xattr -dr com.apple.quarantine '/Applications/${APP_NAME}.app'\" with administrator privileges" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "  ✅  Done! You can now open \"${APP_NAME}\" normally."
else
    echo "  ❌  Unlock cancelled or failed."
fi

echo ""
read -n 1 -s -r -p "  Press any key to close..."
