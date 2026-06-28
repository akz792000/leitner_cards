# FlashMind — Google OAuth & Drive Setup

## Google Cloud Project

- **Project name:** FlashMind
- **Project ID:** `flashmind-500712`
- **Console:** https://console.cloud.google.com/apis/credentials?project=flashmind-500712

## Enabled APIs

- **Google Drive API** — required for card/progress sync

---

## OAuth Client IDs

### 1. Web Client
- **Type:** Web application
- **Client ID:** `<WEB_CLIENT_ID>`
- **Used for:** `serverClientId` in `GoogleSignIn.instance.initialize()` (auth_service.dart)
- **Note:** This is used for basic Google Sign-In (profile, email). NOT used for Drive sync.

### 2. Android Client
- **Type:** Android
- **Client ID:** `<ANDROID_CLIENT_ID>`
- **Package name:** `com.flashmind.app`
- **Used for:** Google Sign-In on Android devices (auto-detected by the SDK)

### 3. iOS Client
- **Type:** iOS
- **Client ID:** `<IOS_CLIENT_ID>`
- **Bundle ID:** `com.flashmind.app`
- **Reversed Client ID:** `<IOS_REVERSED_CLIENT_ID>`
- **Used for:** Google Sign-In on iOS devices
- **Configuration files:**
  - `ios/Runner/GoogleService-Info.plist` — contains CLIENT_ID and REVERSED_CLIENT_ID
  - `ios/Runner/Info.plist` — contains `GIDClientID` key and `CFBundleURLSchemes` with reversed client ID

### 4. Desktop Client (OAuth2 loopback flow)
- **Type:** Desktop app
- **Client ID:** `<DESKTOP_CLIENT_ID>`
- **Client Secret:** `<DESKTOP_CLIENT_SECRET>`
- **Used for:** Google Drive sync on macOS/desktop via browser-based OAuth2
- **Flow:** Opens system browser → user consents → redirect to localhost → app receives auth code → exchanges for access/refresh tokens
- **Configured in:** `lib/service/drive_service.dart`

---

## How Drive Auth Works (Desktop)

The native `google_sign_in` plugin uses GIDSignIn on macOS which requires keychain access and proper code signing (provisioning profile). To avoid this complexity, Drive sync uses a **browser-based OAuth2 flow** instead:

1. App starts a temporary HTTP server on `localhost:<random_port>`
2. Opens system browser to `accounts.google.com/o/oauth2/v2/auth` with the Desktop client ID
3. User signs in and grants Drive permissions
4. Google redirects to `http://localhost:<port>?code=...`
5. App captures the authorization code, shows "✅ Signed in!" page in browser
6. Exchanges the code for access + refresh tokens via `oauth2.googleapis.com/token`
7. Access token is used for all Drive API calls (auto-refreshed when expired)

**Scope:** `https://www.googleapis.com/auth/drive` (full Drive access — needed because users may manually place `cards.json` files in the FlashMind folder via Drive web UI, and the `drive.file` scope only allows access to app-created files)

---

## iOS Configuration Files

### `ios/Runner/GoogleService-Info.plist`
Downloaded from Google Cloud Console → iOS client. Contains:
- `CLIENT_ID` — iOS OAuth client ID
- `REVERSED_CLIENT_ID` — URL scheme for redirect
- `BUNDLE_ID` — `com.flashmind.app`

Must be added to the Xcode project's **Copy Bundle Resources** build phase.

### `ios/Runner/Info.plist` additions
```xml
<key>GIDClientID</key>
<string><IOS_CLIENT_ID></string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string><IOS_REVERSED_CLIENT_ID></string>
    </array>
  </dict>
</array>
```

---

## macOS Configuration Files

### `macos/Runner/GoogleService-Info.plist`
Same as iOS — copied to macOS target and added to Xcode project resources.

### `macos/Runner/Info.plist` additions
```xml
<key>GIDClientID</key>
<string><IOS_CLIENT_ID></string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string><IOS_REVERSED_CLIENT_ID></string>
    </array>
  </dict>
</array>
```

### `macos/Runner/DebugProfile.entitlements`
- `com.apple.security.app-sandbox` set to `false` for debug builds (required for keychain access without provisioning)
- `com.apple.security.network.client` — for HTTP requests

---

## Android Configuration

No additional files needed. The Android client ID is auto-detected by the Google Sign-In SDK using the app's package name and SHA-1 signing certificate.

---

## Code Files Involved

| File | Purpose |
|------|---------|
| `lib/service/auth_service.dart` | Google Sign-In (profile/email) via `google_sign_in` plugin |
| `lib/service/drive_service.dart` | Drive REST API wrapper + browser OAuth2 flow (Desktop client ID) |
| `lib/service/drive_sync_service.dart` | Upload/download cards+progress to/from Drive |
| `lib/view/download_screen.dart` | Sync UI — per-deck Download/Upload/Reset buttons |
| `lib/config/dependency_config.dart` | DI registration for DriveService + DriveSyncService |

---

## Google Drive Folder Structure

```
My Drive/
  FlashMind/
    FA_EN/
      cards.json      ← card data (can be manually placed or uploaded by app)
      progress.json   ← learning progress (levels, sub-levels)
    EN_DE/
      cards.json
      progress.json
```

Folder names are derived from `sourceLang_targetLang` (e.g., `FA_EN` for Farsi→English).
