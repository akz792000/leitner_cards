# Known Issues & Fixes

---

## Gradle SSL error (Zscaler / corporate proxy)

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

