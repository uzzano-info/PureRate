#!/bin/bash
set -e

# ============================================================
# PureRate – DMG Installer Creator
# Creates a polished .dmg with Applications symlink and custom icon
# ============================================================

APP_NAME="PureRate"
OUT_APP="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
VOL_NAME="$APP_NAME Installer"
ICON_FILE="AppIcon.icns"

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
cp -R "$OUT_APP" "$TEMP_DIR/"

# Applications symlink for drag-and-drop install
ln -s /Applications "$TEMP_DIR/Applications"

# 1. Create a writable DMG first to set metadata
echo "▸ Creating temporary writable DMG..."
TMP_DMG="temp_build.dmg"
hdiutil create -volname "$VOL_NAME" -srcfolder "$TEMP_DIR" -ov -format UDRW "$TMP_DMG"

# 2. Mount the DMG to set the icon
echo "▸ Mounting DMG and setting volume icon..."
MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse | tail -n1 | cut -f3-)

# Copy the icon to the root of the volume
cp "$ICON_FILE" "$MOUNT_POINT/.VolumeIcon.icns"

# Hide the icon file and set the custom icon bit
SetFile -a V "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -a C "$MOUNT_POINT"

# (Optional) Set background if sampl.png exists
if [ -f "sampl.png" ]; then
    mkdir -p "$MOUNT_POINT/.background"
    cp sampl.png "$MOUNT_POINT/.background/background.png"
    # Note: Modern Finder background setting usually requires AppleScript, 
    # but we'll stick to icons for now as requested.
fi

sync
hdiutil detach "$MOUNT_POINT"

# 3. Convert to compressed read-only DMG
echo "▸ Converting to final compressed DMG..."
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"
rm "$TMP_DMG"
rm -rf "$TEMP_DIR"

# 4. Remove local quarantine flags (helpful for redistribution)
echo "▸ Cleaning up quarantine attributes..."
xattr -cr "$DMG_NAME"

DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
echo ""
echo "✓ DMG created: $(pwd)/$DMG_NAME ($DMG_SIZE)"
echo "✓ Volume icon applied from $ICON_FILE"
