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

---

## Build

### Android APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/apk/release/`

---

## Hive Code Generation

1. Add `part '<name>.g.dart';` at the top of your model file.
2. Run the generator:

```bash
dart run build_runner build
```

---

## Known Issues & Fixes

### Android: No internet access

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

## Assets

### Country Flags
- Source: https://flagdownload.com
- Style: Flat rounded, 256px

### Icons / Emoji
- Source: https://www.flaticon.com/free-icons/emoticons
- Size: 512px
