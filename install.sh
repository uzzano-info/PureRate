#!/bin/bash
set -e

echo "============================================="
echo " PureRate Installer"
echo "============================================="
echo "Downloading latest PureRate version..."

# Create a temporary directory
TMP_DIR=$(mktemp -d)
DMG_PATH="$TMP_DIR/PureRate.dmg"

# Download the DMG
curl -# -L -o "$DMG_PATH" "https://github.com/uzzano-info/PureRate/raw/main/PureRate.dmg"

echo "Mounting DMG..."
# Attach DMG and extract the mount point
MOUNT_INFO=$(hdiutil attach "$DMG_PATH" -nobrowse -noverify -noautoopen)
MOUNT_PATH=$(echo "$MOUNT_INFO" | grep "/Volumes/" | awk -F'\t' '{print $3}')

if [ -z "$MOUNT_PATH" ]; then
    echo "Error: Failed to mount DMG."
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "Installing to /Applications..."
# Remove old version if it exists
if [ -d "/Applications/PureRate.app" ]; then
    rm -rf "/Applications/PureRate.app"
fi

# Copy the app to Applications
cp -R "$MOUNT_PATH/PureRate.app" /Applications/

# Detach the DMG
hdiutil detach "$MOUNT_PATH" -quiet
rm -rf "$TMP_DIR"

echo "Removing macOS quarantine flags (bypassing Gatekeeper 'damaged' error)..."
xattr -cr /Applications/PureRate.app

echo ""
echo "============================================="
echo "✓ PureRate has been successfully installed!"
echo "▶ You can now open it from your Launchpad or Applications folder."
echo "============================================="
