# Android Device Debugging Guide

A step-by-step reference for connecting a physical Android device (Samsung A52 / any Android 11+) to your Mac for Flutter debugging, and fixing common crash issues.

---

## 1. Enable Developer Options on Your Phone

1. Open **Settings**
2. Scroll down → tap **About phone**
3. Tap **Software information**
4. Find **Build number**
5. Tap **Build number 7 times** in a row
6. Enter your PIN/password if prompted
7. You'll see: *"You are now a developer!"*

> Developer Options will now appear in **Settings → Developer options**

---

## 2. Enable USB Debugging (optional — needed for USB cable connection)

1. Go to **Settings → Developer options**
2. Toggle **USB debugging** → ON
3. Connect your phone via USB cable
4. A dialog will appear on your phone: *"Allow USB debugging?"* → tap **Allow**

> ⚠️ Only works with a **data cable** — a charge-only cable will not be detected by your Mac.

---

## 3. Wireless ADB Debugging (recommended if no data cable)

This is the method used for the Samsung A52 since only a USB-C charge cable was available.

### Step 1 — Enable Wireless Debugging on the phone
1. Go to **Settings → Developer options**
2. Scroll down to find **Wireless debugging**
3. Toggle it **ON**
4. A dialog may ask to confirm — tap **Allow**

### Step 2 — Pair your Mac with the phone
1. Inside **Wireless debugging**, tap **Pair device with pairing code**
2. Your phone will show:
   - A **Wi-Fi pairing address** (e.g. `192.168.1.x:PORT`)
   - A 6-digit **pairing code**
3. On your Mac, run:
   ```bash
   ~/Library/Android/sdk/platform-tools/adb pair <IP:PAIRING_PORT>
   ```
   Example:
   ```bash
   ~/Library/Android/sdk/platform-tools/adb pair 192.168.1.42:37467
   ```
4. Enter the **6-digit pairing code** when prompted
5. You should see: `Successfully paired to 192.168.1.42:37467`

> ⚠️ The pairing port and the connection port are **different numbers**.

### Step 3 — Connect to the phone
1. Back on the **Wireless debugging** screen (main screen, not pairing), note the **IP address and port** shown (e.g. `192.168.1.42:42135`)
2. On your Mac, run:
   ```bash
   ~/Library/Android/sdk/platform-tools/adb connect <IP:CONNECTION_PORT>
   ```
   Example:
   ```bash
   ~/Library/Android/sdk/platform-tools/adb connect 192.168.1.42:42135
   ```
3. You should see: `connected to 192.168.1.42:42135`

### Step 4 — Verify the device is visible
```bash
~/Library/Android/sdk/platform-tools/adb devices
```
Expected output:
```
List of devices attached
adb-XXXXXXXX-XXXXXX._adb-tls-connect._tcp    device
```

---

## 4. Run the Flutter App on the Device

```bash
flutter devices   # find your device ID
flutter run --device-id <DEVICE_ID>
```

Example:
```bash
flutter run --device-id adb-R5CR922T78B-8A4dvV._adb-tls-connect._tcp
```

---

## 5. Capture Crash Logs (logcat)

If the app crashes immediately on launch, run **before** opening the app:
```bash
~/Library/Android/sdk/platform-tools/adb logcat -d | grep -E "(flutter|com.flashmind|AndroidRuntime|FATAL)" | tail -50
```

Or stream logs live while launching:
```bash
~/Library/Android/sdk/platform-tools/adb logcat | grep -E "(flutter|com.flashmind|AndroidRuntime|FATAL)"
```

---

## 6. Fix: ClassNotFoundException for MainActivity

### Symptom
App crashes immediately. Logcat shows:
```
java.lang.RuntimeException: Unable to instantiate activity
ComponentInfo{com.flashmind.app/com.flashmind.app.MainActivity}:
java.lang.ClassNotFoundException: Didn't find class "com.flashmind.app.MainActivity"
```

### Root Cause
When the Android package ID (`applicationId`) is changed in `build.gradle.kts`, the `MainActivity.kt` file must also be **moved to a matching directory path**. If you only update the `applicationId` but don't move the Kotlin source file, Android can't find the activity class at runtime.

### Fix

1. **Create the new package directory:**
   ```bash
   mkdir -p android/app/src/main/kotlin/com/flashmind/app
   ```

2. **Move (or recreate) MainActivity.kt with the correct package name:**
   ```kotlin
   // android/app/src/main/kotlin/com/flashmind/app/MainActivity.kt
   package com.flashmind.app

   import io.flutter.embedding.android.FlutterActivity

   class MainActivity : FlutterActivity()
   ```

3. **Delete the old package directory:**
   ```bash
   rm -rf android/app/src/main/kotlin/com/example
   ```

4. **Rebuild and run:**
   ```bash
   flutter run --device-id <DEVICE_ID>
   ```

### Rule to remember
> The folder path under `kotlin/` must **exactly match** the `applicationId`.  
> `applicationId = "com.flashmind.app"` → folder must be `kotlin/com/flashmind/app/`

---

## 7. Renaming Package ID Checklist (full list)

If you ever rename the package again, update **all** of these:

| File | What to change |
|------|---------------|
| `android/app/build.gradle.kts` | `applicationId` and `namespace` |
| `android/app/src/main/kotlin/<old/path>/MainActivity.kt` | Move file + update `package` declaration |
| `ios/Runner.xcodeproj/project.pbxproj` | All `PRODUCT_BUNDLE_IDENTIFIER` entries (3 configs + RunnerTests) |
| `macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_BUNDLE_IDENTIFIER` |
| `macos/Runner.xcodeproj/project.pbxproj` | Bundle IDs |
| `linux/CMakeLists.txt` | `APPLICATION_ID` |
| `windows/CMakeLists.txt` | Project name |
| `web/index.html` | App title |

---

## 8. Quick Reference Commands

```bash
# Check connected devices
~/Library/Android/sdk/platform-tools/adb devices

# Flutter devices list
flutter devices

# Run on specific device
flutter run --device-id <DEVICE_ID>

# View crash logs
~/Library/Android/sdk/platform-tools/adb logcat -d | grep AndroidRuntime | tail -30

# Uninstall old APK from device (if you need a clean install)
~/Library/Android/sdk/platform-tools/adb uninstall com.flashmind.app
```
