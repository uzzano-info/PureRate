#!/bin/bash
set -e

APP_NAME="PureRate"
OUT_APP="$APP_NAME.app"
OUT_MAC_OS="$OUT_APP/Contents/MacOS"
OUT_RESOURCES="$OUT_APP/Contents/Resources"

# Minimum deployment target (matches Info.plist LSMinimumSystemVersion)
MIN_MACOS="14.0"
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macosx${MIN_MACOS}"

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

echo "▸ Signing with hardened runtime..."
codesign --force --sign - --options runtime --timestamp=none \
         --entitlements /dev/stdin "$OUT_MAC_OS/$APP_NAME" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
PLIST
codesign --force --sign - --options runtime --timestamp=none "$OUT_APP"

echo ""
echo "✓ Build complete: $OUT_APP"
echo "  Launch with: open $OUT_APP"
