# FlashMind — Leitner Flashcards

A Flutter flashcard app using the **Leitner spaced-repetition system**.
Cards move up levels when correct, drop to level 0 when wrong.
Create your own decks, sync to Google Drive, study anywhere.

---

## Stack

| | |
|---|---|
| UI | Flutter 3.x / Dart 3.x |
| State / DI | GetX |
| Storage | Hive (local, offline-first) |
| Sync | Google Drive (user's own account) |
| Auth | Google Sign-In (mobile) · Desktop OAuth (browser loopback) |

---

## First-time setup

```bash
flutter pub get
flutter doctor                      # fix anything flagged
flutter doctor --android-licenses   # accept if prompted
```

### Secrets

Create a `.env` file in the project root (already gitignored):

```
GOOGLE_CLIENT_ID=<your-desktop-oauth-client-id>
GOOGLE_CLIENT_SECRET=<your-desktop-oauth-client-secret>
```

These are used for Desktop OAuth and the data upload script. See [`docs/google_oauth_setup.md`](./docs/google_oauth_setup.md) for setup details.

**IDE setup:** In Android Studio → Run → Edit Configurations → Additional run args, add:
```
--dart-define-from-file=.env
```

---

## Connect your phone

### 1 · Enable Developer Options (one-time)

1. Settings → **About phone** → **Software information**
2. Tap **Build number** 7 times in a row
3. Enter your PIN if prompted
4. ✅ Developer options now appears in Settings

### 2 · Add adb to your PATH (one-time)

```bash
echo 'export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc
adb --version   # should print a version number
```

### 3 · Pair and connect via Wireless ADB

On your phone:
1. Settings → Developer options → **Wireless debugging** → ON
2. Tap **"Pair device with pairing code"** → note the IP and **pairing port**

On your Mac:
```bash
# Step 1 — pair (port from "Pair device" screen, e.g. :37467)
adb pair 192.168.x.x:PAIRING_PORT
# enter the 6-digit code shown on your phone

# Step 2 — connect (port from main Wireless debugging screen, e.g. :40001)
adb connect 192.168.x.x:MAIN_PORT
```

> ⚠️ Pairing port and connection port are **always different numbers**.

---

## Install on your phone

Once your phone is connected, use the deploy script:

```bash
./deploy.sh                            # build release APK and install
./deploy.sh --backup                   # back up cards & progress before install, restore after
./deploy.sh --clean                    # flutter clean first, then build and install
./deploy.sh --connect                  # prompts for wireless ADB address, then builds and installs
```

Flags can be combined freely, e.g. `./deploy.sh --clean --backup --connect`.

> **When to use `--backup`:** The app is signed with the debug keystore stored at `~/.android/debug.keystore` on this Mac. As long as you deploy from the **same machine**, the cert always matches and `./deploy.sh` alone is enough — data is preserved automatically, just like a manual APK install.
> Use `--backup` the **first time you deploy from a new machine**, because a different machine has a different keystore, which triggers a cert mismatch and wipes app data.

**About `--backup`:** Backs up your Hive data (cards + progress) before installing and restores it after — use this whenever you're unsure if a reinstall might wipe your data. Your phone shows a confirmation dialog twice; tap **"Back up my data"** each time. The backup is saved locally to `hive_backup.ab` so you can also restore it manually:

```bash
adb restore hive_backup.ab
```

### No ADB? Manual install

```bash
flutter build apk --release
```

APK: `build/app/outputs/apk/release/app-release.apk`

Send it to your phone via Google Drive / Telegram / USB, open it, and tap Install.
*(If prompted: Settings → Security → "Install from unknown sources" → ON)*

---

## Day-to-day development

```bash
flutter run             # debug build, hot reload enabled
flutter run --release   # release build, installs directly on phone
```

| Shortcut (Mac) | Action |
|---|---|
| `⌘ + \` | Hot Reload — keeps app state |
| `⇧ + ⌘ + \` | Hot Restart — resets state |

---

## Flashcard data (`data/`)

Personal flashcard JSON files, mirroring the Google Drive folder structure:

```
data/
  FA_EN/cards.json           ← Farsi → English (5000+ cards)
  EN_DE/cards.json           ← English → Deutsch
  EN_DE_VERBS/cards.json     ← English → Deutsch verbs
  upload_to_drive.py         ← upload script
```

### Upload to Google Drive

After editing a JSON file locally, upload it to Drive:

```bash
python3 data/upload_to_drive.py              # upload all decks
python3 data/upload_to_drive.py FA_EN        # upload only FA_EN
```

First run opens a browser for Google OAuth (token is cached for future runs).
The script reads credentials from `.env` automatically.

> **Note:** `data/` is gitignored — personal card data is never committed.

---

## Docs

- [`docs/product-roadmap.md`](./docs/product-roadmap.md) — product roadmap
- [`docs/google_oauth_setup.md`](./docs/google_oauth_setup.md) — Google OAuth setup
- [`docs/android-device-debugging-guide.md`](./docs/android-device-debugging-guide.md) — detailed ADB steps
- [`docs/known-issues-and-fixes.md`](./docs/known-issues-and-fixes.md) — Gradle SSL, build issues
