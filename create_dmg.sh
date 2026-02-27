#!/bin/bash
set -e

# ============================================================
# PureRate – DMG Installer Creator
# Creates a polished .dmg with Applications symlink
# ============================================================

APP_NAME="PureRate"
OUT_APP="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
VOL_NAME="$APP_NAME Installer"

if [ ! -d "$OUT_APP" ]; then
    echo "✗ Error: $OUT_APP not found. Run ./build.sh first."
    exit 1
fi

echo "=== Creating DMG Installer ==="

# Clean previous
[ -f "$DMG_NAME" ] && rm "$DMG_NAME"

# Build staging directory
TEMP_DIR=$(mktemp -d)
echo "▸ Staging app bundle..."
cp -a "$OUT_APP" "$TEMP_DIR/"

# Applications symlink for drag-and-drop install
ln -s /Applications "$TEMP_DIR/Applications"

# Background image (optional)
if [ -f "sampl.png" ]; then
    mkdir -p "$TEMP_DIR/.background"
    cp sampl.png "$TEMP_DIR/.background/background.png"
fi

echo "▸ Creating compressed DMG..."
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_NAME"

rm -rf "$TEMP_DIR"

DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
echo ""
echo "✓ DMG created: $(pwd)/$DMG_NAME ($DMG_SIZE)"
