# Google Cloud OAuth Setup Guide — FlashMind

> No Firebase. FlashMind uses `google_sign_in` v7 directly with Google Cloud OAuth.
> All data is local (Hive). Google Drive sync (planned) uses each user's own Drive — zero server cost.

---

## 1 · Create Google Cloud Project

1. Go to **https://console.cloud.google.com**
2. Click **"Select a project"** (top bar) → **"NEW PROJECT"**
3. Project name: **FlashMind**
4. Click **Create**
5. Wait for it to be created, then select it

---

## 2 · Configure OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**
2. **Branding** tab:
   - App name: **FlashMind**
   - User support email: your email
   - Developer contact email: your email
   - Click **Save**
3. **Audience** tab:
   - User type: **External**
   - Click **Save**

> The app will be in "Testing" mode initially — only test users you add can sign in.
> To allow anyone to sign in, you'll need to **Publish** the app later (Audience → Publish).

---

## 3 · Create OAuth Client IDs

Go to **APIs & Services → Credentials** → click **"+ CREATE CREDENTIALS" → "OAuth client ID"**

### 3.1 — Android Client

| Field | Value |
|---|---|
| Application type | **Android** |
| Name | `FlashMind Android` |
| Package name | `com.flashmind.app` |
| SHA-1 certificate fingerprint | `F6:FB:C5:4E:6F:EC:89:B8:F0:85:2A:C5:D1:B4:DC:39:FE:DC:81:84` |

> This is the **debug** SHA-1. For release builds, you'll need to add a second Android client
> with the release keystore SHA-1 (see Section 6).

### How to get your debug SHA-1

```bash
cd android && ./gradlew signingReport
```

Look for `SHA1:` under `Variant: debug`.

### 3.2 — Web Client

| Field | Value |
|---|---|
| Application type | **Web application** |
| Name | `FlashMind Web` |
| Authorized redirect URIs | *(leave empty)* |

> ⚠️ **Copy the Client ID** — you need it in the Flutter code (`serverClientId` parameter).
> It looks like: `123456789-abcdef.apps.googleusercontent.com`

### 3.3 — iOS Client (for future App Store release)

| Field | Value |
|---|---|
| Application type | **iOS** |
| Name | `FlashMind iOS` |
| Bundle ID | `com.flashmind.app` |

> After creating, copy the **Client ID** and update `GIDClientID` in:
> - `macos/Runner/Info.plist`
> - `ios/Runner/Info.plist`
>
> Also update the **reversed client ID** in `CFBundleURLTypes` URL scheme.

---

## 4 · Update the Flutter App

### 4.1 — `lib/service/auth_service.dart`

Set the `serverClientId` in `initialize()` with the **Web** client ID:

```dart
await GoogleSignIn.instance.initialize(
  serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
);
```

### 4.2 — `macos/Runner/Info.plist` (for macOS/iOS builds)

```xml
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_REVERSED_IOS_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

---

## 5 · Checklist

- [x] Google Cloud project created (`flashmind-5de9c`)
- [x] OAuth consent screen configured (Branding + Audience)
- [x] Android OAuth client created — `999687772055-tf7eimslt4tpnp11bdn909hg9s63vom2.apps.googleusercontent.com`
- [x] Web OAuth client created — `999687772055-v2b76t4i62rma2u2t5o51a2f1dvkrj0j.apps.googleusercontent.com`
- [ ] iOS OAuth client created (needed for iOS/macOS)
- [x] `serverClientId` set in `auth_service.dart` (Web client ID)
- [ ] `GIDClientID` updated in `Info.plist` (update when iOS client is created)
- [ ] URL scheme updated in `Info.plist` (reversed iOS client ID)
- [x] Test sign-in on Android device ✅
- [x] Test user added (OAuth consent screen → Audience)
- [x] Debug SHA-1: `CD:DB:56:C0:DA:EA:EF:41:BD:4E:1D:8F:1B:2B:42:FF:12:FF:AD:43`

---

## 6 · Release Build Notes

For Google Play release:

1. Generate a release keystore:
   ```bash
   keytool -genkey -v -keystore flashmind-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias flashmind
   ```
2. Get the release SHA-1:
   ```bash
   keytool -list -v -keystore flashmind-release.jks -alias flashmind
   ```
3. Create a **second Android OAuth client** in Google Cloud Console with the release SHA-1
4. Or use **Google Play App Signing** — in that case, use the SHA-1 from Google Play Console

---

## 7 · Auth Flow

```
App starts
  └→ AuthService.init()
       ├→ GoogleSignIn.instance.initialize(serverClientId: WEB_CLIENT_ID)
       ├→ Listen to authenticationEvents stream
       └→ attemptLightweightAuthentication() (silent restore)
            ├→ Success → user is set → HomeScreen
            └→ No session → user is null → LoginScreen

User taps "Sign in with Google"
  └→ AuthService.signInWithGoogle()
       └→ GoogleSignIn.instance.authenticate()
            └→ Success → authenticationEvents fires → user is set → HomeScreen

User taps "Sign Out"
  └→ AuthService.signOut()
       └→ GoogleSignIn.instance.signOut()
            └→ authenticationEvents fires → user is null → LoginScreen
```

---

## 8 · Google Drive Sync (Planned — Phase 5)

### Storage
Uses Google Drive's `appDataFolder` — a hidden app-specific folder in each user's Drive.

```
appDataFolder/
  manifest.json           ← deck list + timestamps
  deck_{deckId}.json      ← deck info + cards + progress
```

### Additional scope needed
```
https://www.googleapis.com/auth/drive.appdata
```

### Sync algorithm
1. On app open (if online): compare local vs Drive timestamps
2. Per deck: newer version wins (last-write-wins)
3. After study session: mark deck dirty locally
4. On app pause: push dirty decks to Drive
5. Deletions tracked via tombstone list

---

## 9 · macOS Debug Note

Google Sign-In on macOS requires a **Desktop** type OAuth client ID (separate from iOS).
In debug mode, the auth guard (`_AuthGate` in `route_config.dart`) skips authentication
and goes straight to HomeScreen. This only affects macOS debug builds — Android and iOS
work normally.

---

## 10 · Deleting a Google Cloud Project

If you need to start over:

1. Go to **https://console.cloud.google.com/cloud-resource-manager**
2. Find your project → click the **⋮ (three dots)** → **"Delete"**
3. Type the project ID to confirm → click **"SHUT DOWN"**
4. Project enters "pending deletion" for 30 days (can be restored during this period)
5. Create a new project and follow Sections 1–4 again

> ⚠️ Deleting a project removes ALL OAuth client IDs. The app will stop authenticating
> until you create new credentials and update the code.

---

## 11 · Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `serverClientId must be provided on Android` | Missing Web client ID in `initialize()` | Add `serverClientId` parameter |
| `keychain error` (macOS) | macOS sandbox blocks keychain | Disable sandbox in `DebugProfile.entitlements` or use Desktop OAuth client |
| `SIGN_IN_FAILED` (Android) | SHA-1 not registered | Add debug/release SHA-1 to Android OAuth client |
| `ApiException: 10` | Wrong OAuth config | Verify package name + SHA-1 match in Google Cloud Console |
| `ApiException: 12500` | OAuth consent screen incomplete | Fill in all required fields in consent screen |
