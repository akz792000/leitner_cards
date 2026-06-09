# Android Device Debugging — Samsung A52s

---

## Enable Developer Options (one-time)

Settings → About phone → Software information → **tap Build number 7 times** → enter PIN
✅ Developer options now appears in Settings.

---

## Add adb to PATH (one-time)

```bash
echo 'export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## Wireless ADB (every session)

**On phone:** Settings → Developer options → Wireless debugging → ON
→ tap **"Pair device with pairing code"** → note IP + pairing port

```bash
# Step 1 — pair (port from "Pair device" screen)
adb pair 192.168.x.x:PAIRING_PORT
# enter 6-digit code shown on phone

# Step 2 — connect (port from main Wireless debugging screen)
adb connect 192.168.x.x:MAIN_PORT
```

> ⚠️ Pairing port ≠ connection port — they are always different.

Verify: `adb devices` — should show your phone.

---

## Run / install

```bash
flutter run --release        # build + install in one command
./deploy.sh                  # same via the project script
```

---

## Crash logs

```bash
adb logcat -d | grep -E "(flutter|com.flashmind|FATAL)" | tail -50
```

---

## Fix: ClassNotFoundException (MainActivity)

**Symptom:** App crashes on launch — `Didn't find class "com.flashmind.app.MainActivity"`

**Cause:** `applicationId` was renamed in `build.gradle.kts` but the Kotlin file wasn't moved.

**Fix:**
```bash
mkdir -p android/app/src/main/kotlin/com/flashmind/app
# recreate MainActivity.kt with package com.flashmind.app
rm -rf android/app/src/main/kotlin/com/example
flutter run
```

> Rule: folder path under `kotlin/` must exactly match `applicationId`.

