#!/bin/bash
# deploy.sh — Build and install FlashMind on the connected Android device.
#
# Usage:
#   ./deploy.sh                # build release APK and install
#   ./deploy.sh --clean        # flutter clean first, then build and install
#   ./deploy.sh --connect      # prompt for wireless ADB connect before building
#   ./deploy.sh --backup       # back up Hive data before install, restore after
#                              # (combine flags freely, e.g. --clean --backup)
#
# --backup notes:
#   Android will show a confirmation dialog on the phone during backup AND
#   restore — unlock the screen and tap "Back up my data" / confirm when prompted.
#   The backup file is saved to ./hive_backup.ab and kept after the run so you
#   can restore it manually with: adb restore hive_backup.ab
#
# Prerequisites:
#   - adb in PATH (or at ~/Library/Android/sdk/platform-tools/adb)
#   - Phone connected via USB or wireless ADB (see docs/android-device-debugging-guide.md)

set -e

ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
PACKAGE="com.flashmind.app"
BACKUP_FILE="./hive_backup.ab"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

# ── helpers ──────────────────────────────────────────────────────────────────
green()  { printf "\033[0;32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[0;33m%s\033[0m\n" "$*"; }
red()    { printf "\033[0;31m%s\033[0m\n" "$*"; }
blue()   { printf "\033[0;34m%s\033[0m\n" "$*"; }

# ── parse args ────────────────────────────────────────────────────────────────
CLEAN=false
CONNECT=false
BACKUP=false
for arg in "$@"; do
  case $arg in
    --clean)   CLEAN=true ;;
    --connect) CONNECT=true ;;
    --backup)  BACKUP=true ;;
  esac
done

# ── optional: wireless ADB connect ───────────────────────────────────────────
if $CONNECT; then
  yellow "Enter your phone's wireless ADB address (e.g. 192.168.1.42:5555):"
  read -r ADB_ADDRESS
  "$ADB" connect "$ADB_ADDRESS"
  echo ""
fi

# ── check device is reachable and resolve serial ──────────────────────────────
DEVICE_SERIAL=$("$ADB" devices 2>/dev/null \
  | grep -v "^List" | grep -v "^$" | grep "device$" \
  | awk '{print $1}' | head -1)

if [ -z "$DEVICE_SERIAL" ]; then
  red "No Android device found. Connect your phone via USB or run:"
  red "  ./deploy.sh --connect"
  red "  (see docs/android-device-debugging-guide.md for wireless ADB steps)"
  exit 1
fi

green "Device found: $DEVICE_SERIAL ✓"

# ── backup Hive data before install ──────────────────────────────────────────
if $BACKUP; then
  if "$ADB" -s "$DEVICE_SERIAL" shell pm list packages 2>/dev/null | grep -q "$PACKAGE"; then
    blue ""
    blue "📦 Backing up Hive data before install..."
    blue "   👉 On your phone: unlock the screen and tap 'Back up my data' when prompted."
    blue "      Waiting up to 60 seconds for you to confirm..."
    blue ""

    rm -f "$BACKUP_FILE"
    # adb backup blocks until the phone confirms; the file grows as data streams in.
    "$ADB" -s "$DEVICE_SERIAL" backup -f "$BACKUP_FILE" -noapk "$PACKAGE" &
    BACKUP_PID=$!

    # Poll until file size stabilises (unchanged for 4 consecutive 2-second checks).
    MAX_WAIT=60
    elapsed=0
    prev_size=0
    stable=0
    while [ $elapsed -lt $MAX_WAIT ]; do
      sleep 2
      elapsed=$((elapsed + 2))
      curr_size=$(wc -c < "$BACKUP_FILE" 2>/dev/null || echo 0)
      if [ "$curr_size" -gt 100 ] && [ "$curr_size" -eq "$prev_size" ]; then
        stable=$((stable + 1))
        [ $stable -ge 4 ] && break
      else
        stable=0
      fi
      prev_size=$curr_size
    done

    wait $BACKUP_PID 2>/dev/null || true

    BACKUP_SIZE=$(wc -c < "$BACKUP_FILE" 2>/dev/null | tr -d ' ' || echo 0)
    if [ "$BACKUP_SIZE" -gt 100 ]; then
      green "   ✓ Backup saved to $BACKUP_FILE (${BACKUP_SIZE} bytes)"
    else
      yellow "   ⚠️  Backup file is empty — phone may not have confirmed in time."
      yellow "   Continuing with install. Your existing data may be at risk if certs differ."
    fi
  else
    yellow "App not installed yet — skipping backup (nothing to back up)."
  fi
fi

# ── build ─────────────────────────────────────────────────────────────────────
if $CLEAN; then
  yellow "Running flutter clean..."
  flutter clean
  flutter pub get
fi

yellow "Building release APK..."
flutter build apk --release --android-skip-build-dependency-validation

# ── install via adb directly (avoids interactive device picker) ───────────────
yellow "Installing on device $DEVICE_SERIAL..."
INSTALL_OUTPUT=$("$ADB" -s "$DEVICE_SERIAL" install -r "$APK_PATH" 2>&1 || true)

if echo "$INSTALL_OUTPUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
  yellow ""
  yellow "⚠️  Signing certificate mismatch — the old app must be removed first."
  yellow "   This WILL wipe all on-device data for $PACKAGE."
  if $BACKUP && [ -f "$BACKUP_FILE" ] && [ "$(wc -c < "$BACKUP_FILE" | tr -d ' ')" -gt 100 ]; then
    yellow "   A backup exists at $BACKUP_FILE — data will be restored after install."
  else
    yellow "   No valid backup found — data will be permanently lost."
  fi
  printf "   Continue? [y/N] "
  read -r CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    red "Aborted."
    exit 1
  fi
  "$ADB" -s "$DEVICE_SERIAL" uninstall "$PACKAGE"
  "$ADB" -s "$DEVICE_SERIAL" install "$APK_PATH"
elif echo "$INSTALL_OUTPUT" | grep -q "Success"; then
  green "Installed successfully (data preserved) ✓"
else
  red "Install failed:"
  echo "$INSTALL_OUTPUT"
  exit 1
fi

# ── restore Hive data after install ──────────────────────────────────────────
if $BACKUP; then
  BACKUP_SIZE=$(wc -c < "$BACKUP_FILE" 2>/dev/null | tr -d ' ' || echo 0)
  if [ "$BACKUP_SIZE" -gt 100 ]; then
    blue ""
    blue "🔄 Restoring Hive data..."
    blue "   👉 On your phone: unlock the screen and confirm the restore when prompted."
    blue ""
    "$ADB" -s "$DEVICE_SERIAL" restore "$BACKUP_FILE"
    sleep 3
    green "   ✓ Restore complete. Your cards and progress should be intact."
  else
    yellow "No valid backup file found — skipping restore."
  fi
fi

green ""
green "✅ FlashMind installed successfully!"
