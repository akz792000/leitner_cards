#!/bin/bash
# deploy.sh — Build and install FlashMind on the connected Android device.
#
# Usage:
#   ./deploy.sh              # build release APK and install
#   ./deploy.sh --clean      # flutter clean first, then build and install
#   ./deploy.sh --connect    # prompt for wireless ADB connect before building
#
# Prerequisites:
#   - adb in PATH (or at ~/Library/Android/sdk/platform-tools/adb)
#   - Phone connected via USB or wireless ADB (see docs/android-device-debugging-guide.md)

set -e

ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

# ── helpers ──────────────────────────────────────────────────────────────────
green()  { echo "\033[0;32m$*\033[0m"; }
yellow() { echo "\033[0;33m$*\033[0m"; }
red()    { echo "\033[0;31m$*\033[0m"; }

# ── parse args ────────────────────────────────────────────────────────────────
CLEAN=false
CONNECT=false
for arg in "$@"; do
  case $arg in
    --clean)   CLEAN=true ;;
    --connect) CONNECT=true ;;
  esac
done

# ── optional: wireless ADB connect ───────────────────────────────────────────
if $CONNECT; then
  yellow "Enter your phone's wireless ADB address (e.g. 192.168.1.42:5555):"
  read -r ADB_ADDRESS
  "$ADB" connect "$ADB_ADDRESS"
  echo ""
fi

# ── check device is reachable ─────────────────────────────────────────────────
if ! "$ADB" devices | grep -q "device$"; then
  red "No Android device found. Connect your phone via USB or run:"
  red "  ./deploy.sh --connect"
  red "  (see docs/android-device-debugging-guide.md for wireless ADB steps)"
  exit 1
fi

green "Device found ✓"

# ── build ─────────────────────────────────────────────────────────────────────
if $CLEAN; then
  yellow "Running flutter clean..."
  flutter clean
  flutter pub get
fi

yellow "Building release APK..."
flutter build apk --release

# ── install ───────────────────────────────────────────────────────────────────
yellow "Installing on device..."
flutter install --release

green ""
green "✅ FlashMind installed successfully!"
