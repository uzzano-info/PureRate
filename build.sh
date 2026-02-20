#!/bin/bash
set -e

APP_NAME="PureRate"
OUT_APP="$APP_NAME.app"
OUT_MAC_OS="$OUT_APP/Contents/MacOS"
OUT_RESOURCES="$OUT_APP/Contents/Resources"

echo "Creating App Bundle Structure..."
mkdir -p "$OUT_MAC_OS"
mkdir -p "$OUT_RESOURCES"

echo "Copying Info.plist..."
cp Info.plist "$OUT_APP/Contents/"

echo "Copying Assets..."
cp AppIcon.icns "$OUT_RESOURCES/"

echo "Compiling Swift files..."
swiftc PureRateApp.swift LogMonitor.swift AudioDeviceManager.swift \
       -o "$OUT_MAC_OS/$APP_NAME" \
       -O \
       -target arm64-apple-macosx26.3 \
       -framework SwiftUI \
       -framework CoreAudio \
       -framework OSLog \
       -framework Combine

echo "Build complete. Output: $OUT_APP"
echo "You can launch the app by running: open $OUT_APP"
