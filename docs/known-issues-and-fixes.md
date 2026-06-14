# Known Issues & Fixes

---

## KGP (Kotlin Gradle Plugin) build warnings

**Warning:**
```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_tts, speech_to_text
```

**Cause:** `flutter_tts` and `speech_to_text` apply `kotlin-android` themselves in their `build.gradle`. Flutter's built-in Kotlin support makes this redundant and warns about it.

**Fix applied (two parts):**

1. `deploy.sh` already passes `--android-skip-build-dependency-validation` to suppress it during builds.

2. The plugin `build.gradle` files in pub cache are patched — `apply plugin: 'kotlin-android'` and the `buildscript`/KGP classpath block removed from both:
   - `~/.pub-cache/hosted/pub.dev/flutter_tts-4.2.5/android/build.gradle`
   - `~/.pub-cache/hosted/pub.dev/speech_to_text-7.4.0/android/build.gradle`

**⚠️ Patch is fragile** — pub cache lives outside the repo. It will be lost if you:
- Run `flutter pub cache clean`
- Upgrade `flutter_tts` or `speech_to_text` to a new version

**To re-apply the patch** after losing it, for each file remove:
```groovy
// Remove the entire buildscript { ... } block (flutter_tts only)
// Remove this line:
apply plugin: 'kotlin-android'
// Remove this line (flutter_tts only):
implementation "org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version"
```

---



**Error:** `SSLHandshakeException: PKIX path building failed`

**Fix** (already applied in `android/gradle.properties`):
```properties
org.gradle.jvmargs=... -Djavax.net.ssl.trustStoreType=KeychainStore
```
Tells Gradle's JVM to use the macOS Keychain where Zscaler's cert already lives.

---

## Android Studio: "Unable to find bundled Java version"

```bash
cd /Applications/Android\ Studio.app/Contents
ln -s jbr jre
```

---

## Gradle cache bloat

```bash
rm -rf $HOME/.gradle/caches/
```

---

## Android crash: ClassNotFoundException (MainActivity)

**Cause:** `applicationId` renamed in `build.gradle.kts` but `MainActivity.kt` not moved.

See fix in [`android-device-debugging-guide.md`](./android-device-debugging-guide.md#fix-classnotfoundexception-mainactivity).

