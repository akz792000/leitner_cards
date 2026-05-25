# Known Issues & Fixes

---

## Gradle / JVM SSL error with Zscaler (or any corporate proxy)

**Error:** `SSLHandshakeException: PKIX path building failed`

Zscaler (and other corporate proxies) perform SSL inspection using their own root certificate. This certificate is installed in the macOS Keychain automatically, but the JVM that Gradle uses has its own separate trust store and doesn't see it.

**Fix (already applied in `android/gradle.properties`):**

```properties
org.gradle.jvmargs=... -Djavax.net.ssl.trustStoreType=KeychainStore
```

This tells Gradle's JVM to use the macOS Keychain as its trust store — where Zscaler's cert already lives. No need to stop Zscaler or export/import certificates manually.

> If you switch to a new machine or a fresh clone, this flag is already in `android/gradle.properties` so the build will work out of the box.

---

## Android: Uri.https downloads not working

1. Open `android/app/src/main/AndroidManifest.xml`
2. Add before the `<application>` tag:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

---

## Gradle cache bloat

```bash
# macOS / Linux
rm -r $HOME/.gradle/caches/

# Windows
# %USERPROFILE%\.gradle\caches
```

---

## Android Studio: "Unable to find bundled Java version"

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

---

## Flutter build: "Runtime JAR files in the classpath should have the same version"

See: [Stack Overflow answer](https://stackoverflow.com/questions/71347054/flutter-build-runtime-jar-files-in-the-classpath-should-have-the-same-version-t)

---

## Android crash: ClassNotFoundException for MainActivity

**Error:**
```
java.lang.RuntimeException: Unable to instantiate activity
ComponentInfo{com.flashmind.app/com.flashmind.app.MainActivity}:
java.lang.ClassNotFoundException: Didn't find class "com.flashmind.app.MainActivity"
```

**Cause:** After renaming the `applicationId` in `build.gradle.kts`, the `MainActivity.kt` file was still in the old package directory path.

**Fix:** Move the file and update the package declaration to match the new `applicationId`.

See full steps in [`docs/android-device-debugging-guide.md`](./android-device-debugging-guide.md#6-fix-classnotfoundexception-for-mainactivity).
