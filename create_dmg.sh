#!/bin/bash
set -e

APP_NAME="PureRate"
OUT_APP="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"

if [ ! -d "$OUT_APP" ]; then
    echo "Error: $OUT_APP not found. Run ./build.sh first."
    exit 1
fi

echo "Creating DMG package for $APP_NAME..."
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

TEMP_DIR=$(mktemp -d)
echo "Copying app to temporary folder..."
cp -a "$OUT_APP" "$TEMP_DIR/"

# Create a symlink to Applications folder for easy drag-and-drop installing
ln -s /Applications "$TEMP_DIR/Applications"

echo "Running hdiutil..."
hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_NAME"

rm -rf "$TEMP_DIR"
echo "Success! Installable package created at: $(pwd)/$DMG_NAME"
