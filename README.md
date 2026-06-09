# FlashMind — Leitner Flashcards

A Flutter flashcard app using the **Leitner spaced-repetition system**.
Cards move up levels when correct, drop to level 0 when wrong.

**Three decks:** Farsi ↔ English · English ↔ Deutsch · Visual (image-based)

---

## Stack

| | |
|---|---|
| UI | Flutter 3.x / Dart 3.x |
| State / DI | GetX |
| Storage | Hive (local) |
| Card content | Downloaded manually from GitHub JSON |

---

## First-time setup

```bash
flutter pub get
flutter doctor          # fix anything flagged
flutter doctor --android-licenses   # accept if prompted
```

---

## Install on your phone

### Option A — One command (phone already connected)

```bash
./deploy.sh
```

### Option B — With a clean build (use when something feels broken)

```bash
./deploy.sh --clean
```

### Option C — Phone not connected yet

```bash
./deploy.sh --connect   # will ask for your phone's IP:PORT
```

### Option D — Manual (no ADB needed)

```bash
flutter clean
flutter pub get
flutter build apk --release
```

APK output: `build/app/outputs/apk/release/app-release.apk`

Send it to your phone via Google Drive / Telegram / USB, open it, and tap Install.
*(If prompted: Settings → Security → "Install from unknown sources" → ON)*

---

## How to enable Developer Options on Samsung A52s

Do this **once** (survives reboots):

1. Settings → **About phone**
2. Tap **Software information**
3. Tap **Build number** — **7 times** in a row
4. Enter your PIN if prompted
5. ✅ "You are now a developer!" — Developer options now appears in Settings

---

## How to enable Wireless ADB on your Samsung

Do this **once** each time you restart wireless debugging:

### First — add adb to your PATH (one-time setup)

```bash
echo 'export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc
adb --version   # should print a version number
```

### On your phone:
1. Settings → Developer options → **Wireless debugging** → ON
2. Tap **"Pair device with pairing code"** → note the IP and port shown

### On your Mac:
```bash
# Step 1 — pair (use the port from "Pair device" screen, e.g. :37467)
adb pair 192.168.x.x:PAIRING_PORT
# enter the 6-digit code shown on your phone

# Step 2 — connect (use the port from the main Wireless debugging screen, e.g. :40001)
adb connect 192.168.x.x:MAIN_PORT
```

> ⚠️ Pairing port and connection port are **always different numbers**.

Then run `./deploy.sh` or `flutter run --release`.

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

## Docs

- [`docs/android-device-debugging-guide.md`](./docs/android-device-debugging-guide.md) — detailed ADB steps
- [`docs/known-issues-and-fixes.md`](./docs/known-issues-and-fixes.md) — Gradle SSL, build issues
