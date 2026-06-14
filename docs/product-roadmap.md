# FlashMind — Product Roadmap & Publishing Plan

Last updated: 2026-06-15

---

## Current State of the App

**What's already built and working:**
- Leitner spaced-repetition algorithm (levels 0–15)
- 4 decks: FA_EN (Farsi↔English), EN_DE (sentences), EN_DE_VERBS (verbs), Visual
- Speech recognition (STT) with fuzzy matching — grades pronunciation
- Text-to-speech (TTS) with word-by-word highlighting
- Settings screen (13 configurable options)
- Card order: high level first / low level first / random
- AMOLED burn-in protection (pixel shift + auto-dim)
- Study time tracking per deck (foreground-only, paused when backgrounded)
- Dark / light / system theme
- Stats screen per deck
- Download cards from GitHub (manual sync)
- Offline-first — all data stored locally in Hive

**What's missing before publishing:**
- User accounts (each user's data is their own)
- Cloud storage (Firebase — data syncs across devices)
- Users cannot freely create unlimited custom decks yet (partial support exists)
- Privacy policy (required by both stores)
- Onboarding screen (first-launch tutorial)

---

## Phase 1 — Firebase Migration (Accounts + Cloud Sync)

**Goal:** Every user has their own account and their cards/progress live in the cloud.

**Tasks:**
- [ ] Add Firebase to the Flutter project (`flutterfire configure`)
- [ ] Firebase Auth — Google Sign-In + Apple Sign-In (required for App Store)
- [ ] Firestore data model: `/users/{uid}/cards/{cardId}` and `/users/{uid}/progress/{cardId}`
- [ ] Migrate from Hive → Firestore for card and progress storage
- [ ] Keep Hive as local cache (offline-first behaviour preserved)
- [ ] Firebase Storage — host Visual deck images (replace GitHub CDN)
- [ ] Study time stored per user in Firestore instead of local Hive settings

**Firebase cost at scale:**

| Users | Monthly cost (est.) |
|---|---|
| 100 | ~$0–2 |
| 1,000 | ~$5–15 |
| 10,000 | ~$50–150 |

Use Blaze (pay-as-you-go) plan. Requires credit card but charges are tiny at this scale.

---

## Phase 2 — User Card Creation (Content Freedom)

**Goal:** Users are not limited to the pre-loaded decks — they can build their own.

**Tasks:**
- [ ] Allow users to create custom decks (name + language pair)
- [ ] Import cards from CSV / Anki export format
- [ ] Export user's own deck as JSON or CSV
- [ ] Optional: share decks publicly (community library)

**Note:** PersistScreen and MergeScreen already exist — this is mostly unlocking the UI.

---

## Phase 3 — Store Submission (Google Play — Android First)

**Why Android first:** One-time $25 fee vs Apple's $99/year. Faster review process.

**Checklist:**
- [ ] Privacy policy page (can use a free generator like privacypolicygenerator.info)
- [ ] App description (English + Farsi + German = 3 store listings)
- [ ] Screenshots: at least 4 per device type (phone + tablet)
- [ ] Feature graphic (1024×500 banner)
- [ ] App icon already done ✅ (`assets/icon.png`)
- [ ] Set `applicationId = "com.flashmind.app"` ✅ already set
- [ ] `minSdkVersion` — confirm minimum Android version
- [ ] Test on multiple screen sizes
- [ ] Release signing key (`keytool` + `key.properties`)
- [ ] Build release APK / AAB: `flutter build appbundle --release`
- [ ] Submit to Google Play Console

---

## Phase 4 — Apple App Store (iOS)

**Cost:** $99/year Apple Developer Program.

**Extra requirements vs Android:**
- [ ] Apple Sign-In (mandatory if you offer any other social login)
- [ ] Xcode + Mac required for final build/submission ✅ (already on Mac)
- [ ] App Store Connect setup
- [ ] iOS-specific screenshots (different sizes)
- [ ] TestFlight beta before submission

---

## Phase 5 — Monetisation

**Options discussed:**

| Model | Description | Suggested price |
|---|---|---|
| One-time purchase | Pay once, use forever | $1.99–$4.99 |
| Freemium | Free basic, premium features | Free + $2.99–$4.99/month |
| Subscription | Full access monthly/yearly | $4.99/month or $29.99/year |

**Recommendation:** Start with a **one-time purchase ($2.99)** to build user base, then consider subscription if you add ongoing content (new decks, community features).

**What could be "premium":**
- Unlimited custom decks (beyond 3 pre-loaded)
- Cloud sync (Firebase account)
- Advanced stats
- Community shared decks

---

## Competitive Landscape

| App | Strength | Weakness |
|---|---|---|
| Anki | Huge community, very powerful | Ugly UI, steep learning curve |
| Quizlet | Popular, social features | Expensive subscription ($35/year) |
| Duolingo | Gamified, fun | No Leitner, no custom cards |
| Babbel | Structured courses | Expensive, no custom content |

**FlashMind's advantage:** Leitner algorithm + STT pronunciation grading + multilingual (FA/EN/DE) in one clean app.

---

## Technical Debt to Address Before Launch

| Issue | Priority |
|---|---|
| `sync_screen.dart` is orphaned (no-op) | Low — delete before launch |
| Hive adapters manually maintained (no build_runner) | Medium — document clearly |
| KGP pub-cache patch fragile (lost on cache clean) | Medium — automate in deploy script |
| `withOpacity` → `withValues(alpha:)` migration incomplete | Low |
| `RadioListTile` deprecated API in settings_screen | Low |

---

## Notes from Planning Session (2026-06-15)

- User has a Google account — Firebase is the natural backend choice
- Data size estimate: ~52,000 Firestore documents (cards + progress across all decks)
  - Storage: ~20 MB — well within free tier
  - Reads: initial sync exceeds 50k/day free limit → use Blaze plan
  - Ongoing cost: < $0.10/month at personal use scale
- Decision to migrate to Firebase deferred — will revisit when ready for multi-user launch
