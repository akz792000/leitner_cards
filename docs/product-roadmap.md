# FlashMind — Product Roadmap

Last updated: 2026-06-28

---

## Vision

FlashMind is a **user-driven** flashcard app powered by the Leitner spaced-repetition algorithm. There are no pre-loaded decks — every user signs in, creates their own decks, adds their own cards, and tracks their own progress. All data lives **locally in Hive** (offline-first) and syncs to each user's **own Google Drive** (user-visible `FlashMind/` folder) — zero server cost.

---

## Completed (Phases 1, 2, 4)

- **Auth:** Google Sign-In (mobile + desktop OAuth), auth guard, silent restore, secrets via `.env`/`--dart-define`
- **Deck Management:** Create/edit/delete decks, wizard flow, language picker, icon/color, long-press drag reorder (sortOrder synced to Drive)
- **Study Engine:** Leitner algorithm (levels 0–15), deck-based progress, STT pronunciation grading, TTS with word highlighting, stats per deck, settings in Hive
- **Core features:** Markdown rendering, AMOLED burn-in protection, dark/light/system theme, study time tracking, card ordering options

---

## Phase 3 — Card Management (CRUD) — Remaining

**Tasks:**
- [ ] "Add Card" screen — in-app card creation (source text + target text)
- [ ] Edit existing card in-app
- [ ] Delete individual card (with confirmation)
- [ ] Search within card list
- [ ] Bulk import from CSV file

---

## Phase 5 — Google Drive Sync — Partial ✅

**Goal:** Sync deck data to each user's own Google Drive. Zero server cost.

**Storage:** Google Drive user-visible folder (full Drive scope — users can manually manage files).

```
My Drive/
  FlashMind/
    FA_EN/
      cards.json        ← card data
      progress.json     ← study progress
      deck.json         ← deck metadata (name, color, icon, sortOrder)
    EN_DE/
      ...
```

**Tasks:**
- [x] DriveService: REST API calls via `http` package (list, create, update, download, delete)
- [x] Platform-specific OAuth: mobile (google_sign_in) / desktop (browser loopback)
- [x] Upload: cards.json, progress.json, deck.json per deck folder
- [x] Download: merge remote cards/progress into local Hive
- [x] Deck metadata sync (name, color, icon, sortOrder via deck.json)
- [x] Cloud-only deck discovery — detect Drive folders not yet local
- [x] Sync screen with checkboxes and batch Download/Upload/Reset
- [x] Manual cloud folder scan (☁ button)
- [x] Compact JSON uploads (skip null/empty fields)
- [x] Pretty-printed JSON for readability
- [x] Secrets moved to .env / --dart-define (not in source)
- [ ] Auto-sync on app open (background, if online)
- [ ] Push dirty decks on app pause/background
- [ ] Sync conflict resolution (currently last-write-wins)
- [ ] Handle deletions via tombstone list
- [ ] Visual indicator: sync status in app bar (syncing / synced / offline)
- [ ] Offline detection and graceful fallback

---

## Phase 6 — Polish & Pre-Launch Prep

**Goal:** Make the app store-ready.

**Tasks:**
- [ ] Onboarding screen (first-launch tutorial — 3-4 slides explaining the app)
- [ ] Privacy policy page (hosted on a free site like GitHub Pages)
- [ ] Terms of service page
- [ ] Empty states — friendly UI when user has no decks / no cards
- [ ] Error handling — network errors, auth errors, graceful fallbacks
- [ ] Loading states — skeletons / shimmer while fetching data
- [ ] App icon finalized ✅ (already exists: `assets/icon.png`)
- [ ] Splash screen
- [ ] Responsive layout — test phone + tablet
- [ ] Accessibility basics (font scaling, screen reader labels)
- [ ] Remove all hardcoded GitHub URL references
- [x] Delete orphaned code (LoginScreen, AnimatedFlag, IconButtonWidget, export_progress)
- [ ] Fix technical debt:
  - [ ] `withOpacity` → `withValues(alpha:)` migration
  - [ ] `RadioListTile` deprecated API in settings_screen
  - [x] Document Hive adapter manual maintenance (comments in .g.dart files)

---

## Phase 7 — Google Play Store (Android)

**Goal:** Publish on Google Play Store.

**Cost:** One-time $25 developer registration fee.

**Tasks:**
- [ ] Create Google Play Developer account ($25)
- [ ] Release signing key:
  - [ ] Generate keystore: `keytool -genkey -v -keystore flashmind.jks -keyalg RSA -keysize 2048 -validity 10000 -alias flashmind`
  - [ ] Create `key.properties` (DO NOT commit to git)
  - [ ] Configure `android/app/build.gradle` for release signing
- [ ] Set `applicationId` — confirm `com.flashmind.app` is available
- [ ] Set `minSdkVersion` (21+ recommended)
- [ ] Build release: `flutter build appbundle --release`
- [ ] Test release build on multiple devices/emulators
- [ ] Prepare store listing:
  - [ ] App title: "FlashMind — Smart Flashcards"
  - [ ] Short description (80 chars)
  - [ ] Full description (4000 chars) — English + Farsi + German
  - [ ] Screenshots: min 4 per device type (phone + 7" tablet + 10" tablet)
  - [ ] Feature graphic: 1024×500 banner
  - [ ] Category: Education
  - [ ] Content rating questionnaire
  - [ ] Privacy policy URL (mandatory)
  - [ ] Data safety section (declare Google Sign-In + Google Drive usage)
- [ ] Submit to Google Play Console
- [ ] Review typically takes 1–3 days for first submission
- [ ] Set up Google Play Console alerts (crashes, reviews)

**Pricing setup (Google Play):**
- Go to **Google Play Console → Monetize → Products → App pricing**
- Set as **paid app: €0.99 / $0.99**
- Google takes **15% commission** (first $1M/year) → you keep ~€0.85 per sale
- Or set as **free + in-app purchase** (see Monetisation section below)

---

## Phase 8 — Apple App Store (iOS)

**Goal:** Publish on Apple App Store.

**Cost:** $99/year Apple Developer Program.

**Tasks:**
- [ ] Enroll in Apple Developer Program ($99/year)
- [ ] Apple Sign-In — **mandatory** if you offer Google Sign-In
- [ ] Configure Xcode project:
  - [ ] Bundle ID: `com.flashmind.app`
  - [ ] Signing & Capabilities (automatic signing with developer account)
  - [ ] Set deployment target (iOS 14+ recommended)
- [ ] Build: `flutter build ipa --release`
- [ ] TestFlight — upload build for beta testing
  - [ ] Test on physical iPhone + iPad
  - [ ] Invite a few beta testers
- [ ] Prepare App Store Connect listing:
  - [ ] App name, subtitle, description
  - [ ] Screenshots: iPhone 6.7" + 6.5" + iPad Pro 12.9" (required sizes)
  - [ ] App preview video (optional but helps conversion)
  - [ ] Keywords (100 chars — "flashcards, leitner, learn, vocabulary, languages")
  - [ ] Privacy policy URL (mandatory)
  - [ ] App Privacy "nutrition labels" (declare data usage)
  - [ ] Age rating
- [ ] Submit for review (typically 1–7 days)
- [ ] Be prepared for rejection feedback — Apple is stricter than Google

**Pricing setup (App Store):**
- App Store Connect → Pricing and Availability
- Set price tier: **Tier 1 = $0.99 / €0.99**
- Apple takes **15% commission** (Small Business Program, <$1M revenue) → you keep ~€0.85 per sale
- Apply for **Apple Small Business Program** to get 15% rate (default is 30%)

---

## Phase 9 — Monetisation Strategy

### Recommended Model: **Freemium**

| Tier | What's included | Price |
|------|----------------|-------|
| **Free** | 1 deck, up to 50 cards, full Leitner algorithm, STT/TTS | Free |
| **Premium** | Unlimited decks, unlimited cards, cloud sync, bulk import/export, advanced stats | **€0.99 / $0.99 one-time** |

### Why this model:
- **Low price (€0.99)** removes friction — impulse buy territory
- **Free tier** lets users try before buying → better reviews, more downloads
- **One-time purchase** (not subscription) is more appealing for a utility app at this price point
- Subscriptions make sense at $5+/month — at €0.99 users expect "buy once, own forever"

### Implementation:
- [ ] Use **RevenueCat** (free for <$2.5K/month revenue) or **in_app_purchase** Flutter plugin
- [ ] Google Play: create in-app product "premium_unlock" (managed product, €0.99)
- [ ] App Store: create in-app purchase "premium_unlock" (non-consumable, €0.99)
- [ ] Gate check in app: `isPremium ? allow : showUpgradeDialog`
- [ ] Restore purchases button (required by Apple)
- [ ] Receipt validation (client-side or via a lightweight serverless function)

### Revenue projections:

| Downloads/month | Conversion (5%) | Revenue (after store cut) |
|----------------|-----------------|--------------------------|
| 100 | 5 premium | ~€4.25/month |
| 1,000 | 50 premium | ~€42.50/month |
| 10,000 | 500 premium | ~€425/month |
| 50,000 | 2,500 premium | ~€2,125/month |

### Alternative: Paid app (no free tier)
- Set app price to €0.99 on both stores
- Simpler — no in-app purchase logic needed
- Risk: fewer downloads (people hesitate to pay upfront for unknown apps)
- Better if you have strong marketing/word-of-mouth

### Server costs:

**Zero.** All data lives in each user's own Google Drive. No backend to pay for. Revenue is pure profit minus store commission (15%).

---

## Phase 10 — Post-Launch Growth

**Goal:** Grow user base and improve the app based on feedback.

**Tasks:**
- [ ] Crash monitoring (Sentry free tier or similar)
- [ ] Analytics (consider privacy-friendly alternatives or store-built-in analytics)
- [ ] Respond to store reviews promptly
- [ ] Regular updates (every 2–4 weeks) — stores reward active apps
- [ ] Localize store listings (English, German, Farsi, Spanish, French)
- [ ] ASO (App Store Optimization) — optimize title, description, keywords
- [ ] Social media presence (Instagram, Twitter) — share language learning tips
- [ ] Consider adding more languages to the language picker
- [ ] Community features (optional, future): share decks publicly, deck marketplace
- [ ] Referral system: "invite a friend, both get premium free"

---

## Competitive Landscape

| App | Strength | Weakness |
|-----|----------|----------|
| Anki | Huge community, very powerful | Ugly UI, steep learning curve, $24.99 on iOS |
| Quizlet | Popular, social features | Expensive subscription ($35/year) |
| Duolingo | Gamified, fun | No Leitner, no custom cards |
| Babbel | Structured courses | Expensive, no custom content |
| Memrise | Good UX, community decks | Subscription-based ($8.49/month) |

**FlashMind's edge:**
- €0.99 one-time vs competitors' subscriptions
- Leitner algorithm (proven spaced repetition)
- STT pronunciation grading (unique at this price)
- Fully customizable — any language pair
- Clean, modern UI
- Offline-first with cloud sync

---

## Timeline Estimate

| Phase | Duration | Status |
|-------|----------|--------|
| ~~Phase 1 — Google Sign-In~~ | — | ✅ Done |
| ~~Phase 2 — Deck Management~~ | — | ✅ Done |
| Phase 3 — Card CRUD | 1–2 weeks | 🟡 In-app add/edit/delete remaining |
| ~~Phase 4 — Study Engine~~ | — | ✅ Done |
| Phase 5 — Google Drive Sync | 1–2 weeks | 🟡 Auto-sync, conflict resolution remaining |
| Phase 6 — Polish | 1–2 weeks | 🟡 UI polish, error handling remaining |
| Phase 7 — Google Play | 1 week | ⬜ Not started |
| Phase 8 — App Store | 1 week | ⬜ Not started |
| Phase 9 — Monetisation | 1 week | ⬜ Not started |
| Phase 10 — Post-Launch | Ongoing | ⬜ Not started |
| **Total to first store launch** | **~7–9 weeks** | **~60% complete** |
