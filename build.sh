#!/bin/bash
set -e

APP_NAME="PureRate"
OUT_APP="$APP_NAME.app"
OUT_MAC_OS="$OUT_APP/Contents/MacOS"
OUT_RESOURCES="$OUT_APP/Contents/Resources"

# ── Code-Signing Identity ──
# Set SIGN_IDENTITY env var to your Developer ID, e.g.:
#   export SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
# If not set, falls back to ad-hoc signing (will be blocked by Gatekeeper).
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

# Minimum deployment target (matches Info.plist LSMinimumSystemVersion)
MIN_MACOS="14.0"
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macosx${MIN_MACOS}"

echo "=== PureRate Build ==="
echo "Target: $TARGET"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "⚠ Signing: ad-hoc (set SIGN_IDENTITY for Developer ID)"
else
    echo "✓ Signing: $SIGN_IDENTITY"
fi
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

# ── Signing ──
if [ "$SIGN_IDENTITY" = "-" ]; then
    TIMESTAMP_FLAG="--timestamp=none"
else
    TIMESTAMP_FLAG="--timestamp"
fi

echo "▸ Signing with hardened runtime..."
codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime $TIMESTAMP_FLAG \
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
codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime $TIMESTAMP_FLAG "$OUT_APP"

echo ""
echo "✓ Build complete: $OUT_APP"
echo "  Launch with: open $OUT_APP"
