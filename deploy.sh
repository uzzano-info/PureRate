#!/bin/bash
set -e

# ============================================================
# PureRate – Full Deploy Pipeline
# Builds app, creates DMG, and optionally notarizes
#
# USAGE:
#   # Ad-hoc (no Developer ID):
#   ./deploy.sh
#
#   # With Developer ID signing + notarization:
#   export SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
#   export APPLE_ID="your@apple.id"
#   export TEAM_ID="YOUR_TEAM_ID"
#   export APP_PASSWORD="app-specific-password"
#   ./deploy.sh
# ============================================================

echo "╔══════════════════════════════════════════╗"
echo "║     PureRate – Full Deploy Pipeline      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Step 1: Build ──
echo "━━━ Step 1/2: Building App ━━━"
./build.sh
echo ""

# ── Step 2: Create DMG (+ Notarize if credentials set) ──
echo "━━━ Step 2/2: Creating DMG Installer ━━━"
./create_dmg.sh
echo ""

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          Deploy Complete! 🎉             ║"
echo "╠══════════════════════════════════════════╣"
echo "║                                          ║"
echo "║  App:     PureRate_3.0.app               ║"
echo "║  DMG:     PureRate_3.0.dmg               ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝"
