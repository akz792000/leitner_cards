# Android Data Backup & Recovery Guide — FlashMind

> How to back up and restore Hive data when reinstalling the app with a different signing certificate.

---

## When You Need This

- Switching debug keystores (new SHA-1 for Google Cloud OAuth)
- Moving from debug to release signing
- Any situation where the app must be uninstalled and reinstalled with a different certificate

> ⚠️ Android requires the same signing certificate to update an app in place.
> A certificate mismatch forces a full uninstall, which **wipes all app data**.

---

## Prerequisites

- `adb` installed (comes with Android SDK)
- Phone connected via USB or wireless ADB
- App currently installed on the phone

```bash
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
```

---

## Step 1 — Install a Debug Build (Same Certificate)

You need a **debuggable** build signed with the **same certificate** as the currently installed app.
This is required because `adb shell run-as` only works with debug builds.

```bash
# If the currently installed app uses the OLD keystore, make sure ~/.android/debug.keystore
# is the OLD one before building:
flutter build apk --debug --android-skip-build-dependency-validation
```

Install the debug build **over** the existing app (preserves data):

```bash
$ADB install -r build/app/outputs/flutter-apk/app-debug.apk
```

> If you get `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, the certificates don't match.
> You need to use the correct keystore that matches the installed app.

---

## Step 2 — Pull Hive Data

List the Hive files:

```bash
$ADB shell "run-as com.flashmind.app find . -name '*.hive'"
```

Expected output:
```
./app_flutter/card.hive
./app_flutter/progress.hive
./app_flutter/settings.hive
./app_flutter/studylog.hive
```

Pull each file to a local backup directory:

```bash
mkdir -p hive_data_backup

for f in card.hive progress.hive settings.hive studylog.hive; do
  echo "Pulling $f..."
  $ADB shell "run-as com.flashmind.app cat app_flutter/$f" > "hive_data_backup/$f"
done
```

Verify the backup:

```bash
ls -lh hive_data_backup/
```

You should see files with real sizes (card.hive ~400K+, progress.hive ~100K+).

---

## Step 3 — Switch Keystore & Reinstall

Switch to the new keystore:

```bash
cp ~/.android/debug.keystore.new ~/.android/debug.keystore
```

Uninstall the old app and install the new release:

```bash
$ADB uninstall com.flashmind.app

flutter build apk --release --android-skip-build-dependency-validation
$ADB install build/app/outputs/flutter-apk/app-release.apk
```

---

## Step 4 — Restore Hive Data

First, install a **debug** build with the **new** keystore (needed for `run-as`):

```bash
flutter build apk --debug --android-skip-build-dependency-validation
$ADB uninstall com.flashmind.app
$ADB install build/app/outputs/flutter-apk/app-debug.apk
```

Launch the app briefly to create the data directory, then stop it:

```bash
$ADB shell am start -n com.flashmind.app/.MainActivity
sleep 4
$ADB shell am force-stop com.flashmind.app
```

Push the backed-up Hive files:

```bash
for f in card.hive progress.hive settings.hive studylog.hive; do
  echo "Restoring $f..."
  $ADB shell "run-as com.flashmind.app sh -c 'cat > app_flutter/$f'" < "hive_data_backup/$f"
done
```

Verify the restored files:

```bash
$ADB shell "run-as com.flashmind.app ls -la app_flutter/"
```

---

## Step 5 — Install Release Build

Install the release build over the debug build (same new keystore = data preserved):

```bash
flutter build apk --release --android-skip-build-dependency-validation
$ADB install -r build/app/outputs/flutter-apk/app-release.apk
```

Open the app — your cards, progress, settings, and study logs should all be intact.

---

## Quick Reference — Full Script

```bash
#!/bin/bash
# backup-and-migrate.sh — Back up Hive data, switch keystore, restore data.
set -e

ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
PACKAGE="com.flashmind.app"
BACKUP_DIR="./hive_data_backup"
HIVE_FILES="card.hive progress.hive settings.hive studylog.hive"

echo "=== Step 1: Pull Hive data ==="
mkdir -p "$BACKUP_DIR"
for f in $HIVE_FILES; do
  echo "  Pulling $f..."
  $ADB shell "run-as $PACKAGE cat app_flutter/$f" > "$BACKUP_DIR/$f"
done
ls -lh "$BACKUP_DIR/"

echo ""
echo "=== Step 2: Switch keystore ==="
echo "  Replace ~/.android/debug.keystore with your new keystore now."
read -p "  Press Enter when ready..."

echo ""
echo "=== Step 3: Rebuild and reinstall ==="
$ADB uninstall "$PACKAGE"
flutter build apk --debug --android-skip-build-dependency-validation
$ADB install build/app/outputs/flutter-apk/app-debug.apk

echo ""
echo "=== Step 4: Restore Hive data ==="
$ADB shell am start -n "$PACKAGE/.MainActivity"
sleep 4
$ADB shell am force-stop "$PACKAGE"

for f in $HIVE_FILES; do
  echo "  Restoring $f..."
  $ADB shell "run-as $PACKAGE sh -c 'cat > app_flutter/$f'" < "$BACKUP_DIR/$f"
done

echo ""
echo "=== Step 5: Install release ==="
flutter build apk --release --android-skip-build-dependency-validation
$ADB install -r build/app/outputs/flutter-apk/app-release.apk

echo ""
echo "✅ Done! Open the app to verify your data."
```

---

## Keystore Management

| File | Purpose |
|---|---|
| `~/.android/debug.keystore` | Active debug keystore (used by Gradle) |
| `~/.android/debug.keystore.bak` | Old keystore backup (original SHA-1) |
| `~/.android/debug.keystore.new` | New keystore backup (current SHA-1) |

### Current debug SHA-1

```
CD:DB:56:C0:DA:EA:EF:41:BD:4E:1D:8F:1B:2B:42:FF:12:FF:AD:43
```

### Get SHA-1 from any keystore

```bash
keytool -list -v -keystore ~/.android/debug.keystore -storepass android | grep SHA1
```

---

## Notes

- `adb backup` is deprecated and unreliable on modern Android — use `run-as` + `cat` instead
- `run-as` only works with **debug** builds (release builds are not debuggable)
- Lock files (`.lock`) don't need to be backed up — Hive recreates them
- The backup directory (`hive_data_backup/`) is gitignored — don't commit user data
