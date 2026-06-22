# FlashMind — Product Roadmap

Last updated: 2026-06-22

---

## Vision

FlashMind is a **user-driven** flashcard app powered by the Leitner spaced-repetition algorithm. There are no pre-loaded decks — every user signs in, creates their own decks, adds their own cards, and tracks their own progress. All data lives in Firebase (Firestore) with local caching for offline use.

---

## Current State (What's Already Built)

- Leitner spaced-repetition algorithm (levels 0–15)
- Speech recognition (STT) with fuzzy matching — grades pronunciation
- Dynamic STT timing based on text length
- Text-to-speech (TTS) with word-by-word highlighting
- Markdown rendering for card content
- Settings screen (13 configurable options)
- Card order: high level first / low level first / random
- AMOLED burn-in protection (pixel shift + auto-dim)
- Study time tracking per deck (foreground-only, paused when backgrounded)
- Dark / light / system theme
- Stats screen per deck

---

## Phase 1 — Firebase Setup & Authentication

**Goal:** Every user must sign in before using the app. Firebase becomes the foundation.

**Tasks:**
- [ ] Add Firebase to the Flutter project (`flutterfire configure`)
- [ ] Firebase Auth — Google Sign-In
- [ ] Firebase Auth — Apple Sign-In (mandatory for App Store if offering social login)
- [ ] Login screen — clean UI with Google + Apple sign-in buttons
- [ ] Auth guard — redirect unauthenticated users to login
- [ ] User profile document in Firestore: `/users/{uid}` (name, email, avatar, createdAt)
- [ ] Sign-out functionality

**Firestore structure:**
```
users/
  {uid}/
    profile: { name, email, avatar, createdAt, settings }
    decks/
      {deckId}/
        info: { name, sourceLang, targetLang, icon, color, createdAt, updatedAt, cardCount }
        cards/
          {cardId}: { source, target, groupCode, createdAt, updatedAt }
        progress/
          {cardId}: { boxLevel, nextReview, correctCount, wrongCount, lastStudied }
```

---

## Phase 2 — Deck Management

**Goal:** Users can create, edit, and delete their own decks via a wizard.

**Tasks:**
- [ ] Home screen redesign — dynamic grid/list of user's decks (no hardcoded decks)
- [ ] "Create Deck" button → wizard flow:
  1. Pick source language (e.g., Farsi, English, German, Spanish, French, ...)
  2. Pick target language
  3. Auto-suggest name (e.g., "Farsi → English") — user can edit
  4. Optional: pick icon and color
  5. Confirm → deck created in Firestore
- [ ] Deck edit (rename, change icon/color)
- [ ] Deck delete (with confirmation — deletes all cards + progress)
- [ ] Deck list shows: name, card count, last studied, progress indicator
- [ ] Supported languages list (expandable — stored as config)

---

## Phase 3 — Card Management (CRUD)

**Goal:** Users can add, edit, and delete cards within a deck.

**Tasks:**
- [ ] "Add Card" screen — source text + target text + optional groupCode
- [ ] Edit existing card
- [ ] Delete card (with confirmation)
- [ ] Card list view within a deck (searchable, sortable)
- [ ] Bulk import from JSON or CSV file (for power users / migration)
- [ ] Bulk export deck as JSON or CSV

---

## Phase 4 — Study Engine (Leitner + Progress)

**Goal:** Connect the existing Leitner algorithm to the new Firestore data model.

**Tasks:**
- [ ] Refactor study engine to read cards from Firestore (instead of Hive)
- [ ] Progress tracking writes to Firestore: `/users/{uid}/decks/{deckId}/progress/{cardId}`
- [ ] Study time tracking per deck in Firestore
- [ ] STT pronunciation grading works with any language pair
- [ ] TTS works with any language pair (auto-detect language from deck config)
- [ ] Stats screen reads from Firestore progress data
- [ ] Settings stored per user in Firestore (synced across devices)

---

## Phase 5 — Offline Mode & Sync

**Goal:** App works fully offline and syncs when connectivity returns.

**Tasks:**
- [ ] Hive as local cache — mirror Firestore structure locally
- [ ] On app launch: check connectivity → sync if online, use cache if offline
- [ ] Write operations: save to Hive immediately, queue for Firestore sync
- [ ] Sync service: push pending local changes when back online
- [ ] Pull new/updated data from Firestore on reconnect
- [ ] Conflict resolution: last-write-wins with `updatedAt` timestamps
- [ ] Visual indicator: online/offline status in app bar
- [ ] Firestore offline persistence enabled (built-in Flutter Firestore feature)

---

## Phase 6 — Polish & Pre-Launch Prep

**Goal:** Make the app store-ready.

**Tasks:**
- [ ] Onboarding screen (first-launch tutorial — 3-4 slides explaining the app)
- [ ] Privacy policy page (hosted on a free site like GitHub Pages or Firebase Hosting)
- [ ] Terms of service page
- [ ] Empty states — friendly UI when user has no decks / no cards
- [ ] Error handling — network errors, auth errors, graceful fallbacks
- [ ] Loading states — skeletons / shimmer while fetching data
- [ ] App icon finalized ✅ (already exists: `assets/icon.png`)
- [ ] Splash screen
- [ ] Responsive layout — test phone + tablet
- [ ] Accessibility basics (font scaling, screen reader labels)
- [ ] Remove all hardcoded GitHub URL references
- [ ] Delete orphaned code (`sync_screen.dart`, old download logic)
- [ ] Fix technical debt:
  - [ ] `withOpacity` → `withValues(alpha:)` migration
  - [ ] `RadioListTile` deprecated API in settings_screen
  - [ ] Document Hive adapter manual maintenance

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
- [ ] Set `minSdkVersion` (21+ recommended for Firebase)
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
  - [ ] Data safety section (declare Firebase Auth + Firestore usage)
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
- [ ] Receipt validation (server-side via Firebase Cloud Functions, or client-side)

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

### Firebase costs vs revenue:

| Users | Firebase cost | Revenue needed to break even |
|-------|-------------|------------------------------|
| 100 | ~€0–2/month | 3 sales/month |
| 1,000 | ~€5–15/month | 18 sales/month |
| 10,000 | ~€50–150/month | 177 sales/month |

At 5% conversion rate, you break even at ~3,500 downloads/month.

---

## Phase 10 — Post-Launch Growth

**Goal:** Grow user base and improve the app based on feedback.

**Tasks:**
- [ ] Firebase Crashlytics — monitor crashes in production
- [ ] Firebase Analytics — track user behavior (deck creation, study sessions, retention)
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

| Phase | Duration | Target |
|-------|----------|--------|
| Phase 1 — Firebase Auth | 2 weeks | |
| Phase 2 — Deck Management | 2 weeks | |
| Phase 3 — Card CRUD | 1–2 weeks | |
| Phase 4 — Study Engine | 2 weeks | |
| Phase 5 — Offline Sync | 1–2 weeks | |
| Phase 6 — Polish | 1–2 weeks | |
| Phase 7 — Google Play | 1 week | |
| Phase 8 — App Store | 1 week | |
| Phase 9 — Monetisation | 1 week | |
| Phase 10 — Post-Launch | Ongoing | |
| **Total to first store launch** | **~10–14 weeks** | |
