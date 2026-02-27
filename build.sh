#!/bin/bash
set -e

APP_NAME="PureRate"
OUT_APP="$APP_NAME.app"
OUT_MAC_OS="$OUT_APP/Contents/MacOS"
OUT_RESOURCES="$OUT_APP/Contents/Resources"

# Auto-detect the macOS SDK target from the current system
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1,2)
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macosx${MACOS_VERSION}"

echo "=== PureRate Build ==="
echo "Target: $TARGET"
echo ""

echo "▸ Creating App Bundle Structure..."
rm -rf "$OUT_APP"
mkdir -p "$OUT_MAC_OS"
mkdir -p "$OUT_RESOURCES"

echo "▸ Copying Info.plist..."
cp Info.plist "$OUT_APP/Contents/"

echo "▸ Copying Assets..."
cp AppIcon.icns "$OUT_RESOURCES/"

echo "▸ Compiling Swift files..."
swiftc PureRateApp.swift LogMonitor.swift AudioDeviceManager.swift \
       -o "$OUT_MAC_OS/$APP_NAME" \
       -O \
       -target "$TARGET" \
       -framework SwiftUI \
       -framework CoreAudio \
       -framework OSLog \
       -framework Combine \
       -framework UserNotifications

echo ""
echo "▸ Ad-hoc code signing (prevents Gatekeeper 'damaged' error)..."
codesign --force --deep --sign - "$OUT_APP"

echo ""
echo "✓ Build complete: $OUT_APP"
echo "  Launch with: open $OUT_APP"
