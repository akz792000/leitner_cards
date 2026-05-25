# Leitner Cards

A Flutter flashcard app based on the **Leitner spaced repetition system**, designed to help you memorize content efficiently. Cards move to higher levels when answered correctly and drop back when answered wrong — optimizing review frequency over time.

## Tech Stack

- **Flutter** 3.35.6 / Dart 3.9.2
- **Hive** — local NoSQL storage
- **GetX** — state management
- **go_router** — navigation
- **intl / timezone** — date and scheduling

---

## Setup

### Prerequisites

```bash
# Check partition sizes (macOS)
diskutil list

# Upgrade Homebrew packages
brew upgrade
```

### Install Android tooling

```bash
brew install --cask android-studio
```

In Android Studio, install the following via **SDK Manager**:
- Android SDK (latest stable)
- Android SDK Build-Tools
- Android SDK Command-line Tools
- Android Emulator
- Android SDK Platform-Tools

### Install Flutter

```bash
brew install --cask flutter
```

### Verify setup

```bash
flutter doctor

# Accept Android licenses if prompted
flutter doctor --android-licenses
```

---

## Running the App

```bash
flutter pub get
flutter run
```

### Hot Reload & Hot Restart

Once the app is running, you don't need to stop and restart for every change:

| Action | Shortcut (Mac) | When to use |
|---|---|---|
| **Hot Reload** ⚡ | `⌘ + \` | UI and logic changes — keeps app state |
| **Hot Restart** 🔄 | `⇧ + ⌘ + \` | New variables, `initState` changes — resets state |
| **Full Restart** ▶️ | Stop + Run | New packages, native config, entitlements |

---

## Build

### Android APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

**Output file:**
```
build/app/outputs/apk/release/app-release.apk
```

To install directly on a connected Android device:
```bash
flutter install --release
```

Or copy the APK to your phone via USB / Google Drive / AirDrop and open it.  
*(Enable "Install from unknown sources" in Android Settings → Security if prompted.)*

---

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

**Output file:**
```
build/app/outputs/bundle/release/app-release.aab
```

---

### iOS (on macOS only)

```bash
flutter build ios --release
```

Then open Xcode to archive and export the `.ipa`:
1. `open ios/Runner.xcworkspace`
2. **Product → Archive**
3. **Distribute App → Ad Hoc** (for direct install) or **App Store Connect** (for TestFlight/Store)

---

### Quick reference

| Platform | Command | Output path |
|---|---|---|
| Android APK | `flutter build apk --release` | `build/app/outputs/apk/release/app-release.apk` |
| Android Bundle | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS | `flutter build ios --release` | Archive via Xcode |


## Adding Cards via Supabase

Cards are stored in the `cards` table in Supabase. On each app launch the local Hive database syncs with Supabase — so inserting rows there is the easiest way to seed content.

### Table columns

| Column | Type | Notes |
|---|---|---|
| `id` | integer | Unique ID — use seconds since epoch (safe until 2106) |
| `en` | text | English word/phrase |
| `fa` | text | Farsi translation |
| `de` | text | German translation (leave `""` for English↔Farsi cards) |
| `description` | text | Optional hint shown via the 💡 button |
| `group_code` | integer | `0` = English/Farsi, `1` = Deutsch/English |
| `modified` | timestamptz | UTC timestamp — controls which side wins on sync |

### Insert with curl

```bash
BASE_URL="https://<your-project>.supabase.co"
KEY="<your-anon-key>"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BASE_ID=$(date +%s)   # seconds epoch — increment per card to keep IDs unique

curl -s -X POST "$BASE_URL/rest/v1/cards" \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "[
    {\"id\": $((BASE_ID+1)), \"en\": \"apple\",  \"fa\": \"سیب\",  \"de\": \"\", \"description\": \"A common fruit\", \"group_code\": 0, \"modified\": \"$NOW\"},
    {\"id\": $((BASE_ID+2)), \"en\": \"water\",  \"fa\": \"آب\",   \"de\": \"\", \"description\": \"\",               \"group_code\": 0, \"modified\": \"$NOW\"}
  ]"
```

### Insert via Supabase Dashboard

1. Open **Table Editor → cards** in the [Supabase Dashboard](https://supabase.com/dashboard).
2. Click **Insert row**.
3. Fill in `id` (e.g. current Unix timestamp), `en`, `fa`, `group_code` (`0` for English/Farsi), `modified` (current UTC time), and optionally `description`.
4. Save — the card will appear in the app after the next launch (sync runs at startup).

> **Tip:** `group_code: 0` puts the card under the **English** deck; `group_code: 1` puts it under **Deutsch**.

---

## Hive Code Generation

1. Add `part '<name>.g.dart';` at the top of your model file.
2. Run the generator:

```bash
dart run build_runner build
```

---

## Known Issues & Fixes

### Gradle / JVM SSL error with Zscaler (or any corporate proxy)

**Error:** `SSLHandshakeException: PKIX path building failed`

Zscaler (and other corporate proxies) perform SSL inspection using their own root certificate. This certificate is installed in the macOS Keychain automatically, but the JVM that Gradle uses has its own separate trust store and doesn't see it.

**Fix (already applied in `android/gradle.properties`):**

```properties
org.gradle.jvmargs=... -Djavax.net.ssl.trustStoreType=KeychainStore
```

This tells Gradle's JVM to use the macOS Keychain as its trust store — where Zscaler's cert already lives. No need to stop Zscaler or export/import certificates manually.

> If you switch to a new machine or a fresh clone, this flag is already in `android/gradle.properties` so the build will work out of the box.



On Android, if `Uri.https` downloads are not working:

1. Open `android/app/src/main/AndroidManifest.xml`
2. Add before the `<application>` tag:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### Gradle cache bloat

```bash
# macOS / Linux
rm -r $HOME/.gradle/caches/

# Windows
# %USERPROFILE%\.gradle\caches
```

### Android Studio: "Unable to find bundled Java version"

**macOS**
```bash
cd /Applications/Android\ Studio.app/Contents
ln -s jbr jre
```

**Linux**
```bash
cd ~/android-studio/
ln -s jbr jre
```

**Windows** (run in an elevated terminal)
```powershell
cd "C:\Program Files\Android\Android Studio"
New-Item -ItemType SymbolicLink -Path .\jre -Target .\jbr
```

### Flutter build: "Runtime JAR files in the classpath should have the same version"

See: [Stack Overflow answer](https://stackoverflow.com/questions/71347054/flutter-build-runtime-jar-files-in-the-classpath-should-have-the-same-version-t)

---

## Debugging on Android Device (e.g. Samsung A52)

### Step 1 — Enable Developer Options

1. Go to **Settings → About phone → Software information**
2. Tap **Build number** 7 times rapidly
3. Enter your PIN/password when prompted
4. You'll see **"Developer mode has been turned on"**

### Step 2 — Enable USB Debugging

1. Go back to **Settings** — you'll now see **Developer options** near the bottom
2. Open it and turn on **USB debugging**

### Step 3 — Connect to Mac and view logs

1. Plug the phone into your Mac via USB cable
2. On the phone tap **"Allow"** when asked to trust the computer
3. Verify the device is detected:

```bash
~/Library/Android/sdk/platform-tools/adb devices
```

4. Launch the app on the phone, then capture crash logs:

```bash
~/Library/Android/sdk/platform-tools/adb logcat -d | grep -E "FATAL|AndroidRuntime|flutter|flashmind"
```

### Alternative — Wireless ADB (no cable needed)

Your phone and Mac must be on the **same WiFi network**.

1. Go to **Settings → Developer options → Wireless debugging** → turn it **ON**
2. Tap **"Pair device with pairing code"**
3. Note the **IP:PORT** and **6-digit pairing code** shown on screen
4. On your Mac run:

```bash
~/Library/Android/sdk/platform-tools/adb pair <IP:PORT>
# Enter the 6-digit code when prompted
```

5. Then connect:

```bash
~/Library/Android/sdk/platform-tools/adb connect <IP:PORT>
~/Library/Android/sdk/platform-tools/adb devices
# Should show: adb-xxxxx  device
```

> ⚠️ Use the **Pair** IP:PORT for pairing, then use the **main Wireless debugging** IP:PORT for connecting (they are different ports).



## Assets

### Country Flags
- Source: https://flagdownload.com
- Style: Flat rounded, 256px

### Icons / Emoji
- Source: https://www.flaticon.com/free-icons/emoticons
- Size: 512px
