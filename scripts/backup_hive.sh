#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# backup_hive.sh — Pull Hive database files from a connected
#                   Android device (debug build required).
#
# Usage:  ./scripts/backup_hive.sh
#
# Output: hive_data_backup/<YYYYMMDD_HHMMSS>/
# ─────────────────────────────────────────────────────────────
set -euo pipefail

PKG="${1:-com.flashmind.app}"
HIVE_FILES=("card.hive" "progress.hive" "settings.hive" "studyLog.hive")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/hive_data_backup/$(date +%Y%m%d_%H%M%S)"

# Check ADB connection.
if ! adb get-state &>/dev/null; then
  echo "❌ No device connected. Plug in via USB or connect wirelessly first."
  exit 1
fi

mkdir -p "$BACKUP_DIR"
echo "📦 Backing up Hive data from device..."
echo ""

for f in "${HIVE_FILES[@]}"; do
  echo -n "  $f → "
  if adb exec-out run-as "$PKG" cat "app_flutter/$f" > "$BACKUP_DIR/$f" 2>/dev/null; then
    SIZE=$(wc -c < "$BACKUP_DIR/$f" | tr -d ' ')
    if [ "$SIZE" -gt 0 ]; then
      echo "✅ $(du -h "$BACKUP_DIR/$f" | cut -f1)"
    else
      echo "⚠️  empty (no data yet)"
      rm "$BACKUP_DIR/$f"
    fi
  else
    echo "⚠️  not found (skipped)"
    rm -f "$BACKUP_DIR/$f"
  fi
done

echo ""
echo "✅ Backup saved to:"
echo "   $BACKUP_DIR"
echo ""
ls -lh "$BACKUP_DIR/"
