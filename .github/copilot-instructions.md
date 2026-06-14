# Copilot Instructions — Leitner Cards (FlashMind)

This is the single source of truth for all AI sessions working on this project. Read fully before touching any code.

> 🚨 **NEVER commit or push without the user explicitly saying "commit" or "push". Absolute hard rule — no exceptions, no auto-commits after finishing a task, no "let me commit this for you". Make code changes and STOP.**

---

## 1 · Project Overview

**FlashMind** (`com.flashmind.app`) is a Flutter flashcard app implementing the Leitner spaced-repetition system. Cards move up levels when answered correctly and drop to level 0 when wrong. Four decks:

| Deck | GroupCode enum | Stored string | Fields used |
|---|---|---|---|
| Farsi ↔ English | `GroupCode.faEn` | `"FA_EN"` | `en`, `fa`, `desc` |
| English ↔ Deutsch (sentences) | `GroupCode.enDe` | `"EN_DE"` | `en`, `de`, `desc` |
| English ↔ Deutsch (verbs) | `GroupCode.enDeVerbs` | `"EN_DE_VERBS"` | `en`, `de`, `desc` |
| Visual | `GroupCode.visual` | `"VISUAL"` | `en`, `de`, `image`, `desc` |

**Deutsch sub-deck selection:** Tapping the Deutsch card on `HomeScreen` shows a modal bottom sheet with "Sentences" (`GroupCode.enDe`) and "Verbs" (`GroupCode.enDeVerbs`) options. Both route to `LevelScreen`. Download source for Verbs: `en_de_verbs.json` (same GitHub repo).

---

## 2 · Git & Remotes

| Key | Value |
|---|---|
| GitHub account | `akz792000` |
| Remote | `git@github.personal.com:akz792000/leitner_cards.git` |
| SSH alias | `github.personal.com` → `~/.ssh/id_rsa` |
| Other account | `KarimizandiA` uses `github.com` → `~/.ssh/id_ed25519` |
| Branch | `main` |

---

## 3 · Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.x / Dart SDK `>=3.3.0 <4.0.0` |
| State / DI | GetX (`get: ^4.6.5`) |
| Local storage | Hive (`hive: ^2.2.3`, `hive_flutter: ^1.1.0`) |
| HTTP | `http: ^1.2.2` |
| Responsive sizing | `sizer: ^3.0.5` |
| Timezone | `timezone: ^0.10.1` + `intl: ^0.20.2` |
| Spinner | `flutter_spinkit: ^5.1.0` |
| TTS | `flutter_tts: ^4.2.5` |
| App icon | `flutter_launcher_icons: ^0.14.3` (dev) |
| Linter | `flutter_lints: ^6.0.0` (dev) |

**Assets:**
```
assets/
├── icon.png         # App icon (used by flutter_launcher_icons)
├── image.png        # Profile avatar in AppDrawer header
├── database.png     # (unused)
└── flags/
    ├── en.png
    ├── de.png
    └── fa.png
```

---

## 4 · Project Structure

```
lib/
├── main.dart                            # setup() + MyApp
├── config/
│   ├── app_theme.dart                   # Light + dark ThemeData
│   ├── dependency_config.dart           # GetX DI registration order
│   └── route_config.dart               # Route constants + generateRoute()
├── entity/
│   ├── card_entity.dart                 # Hive model typeId=1
│   ├── card_entity.g.dart              # ⚠️ Manually maintained — do NOT run build_runner
│   ├── hive_type_ids.dart              # cardId=1, progressId=2
│   ├── progress_entity.dart            # Hive model typeId=2
│   └── progress_entity.g.dart         # ⚠️ Manually maintained — do NOT run build_runner
├── enums/
│   ├── group_code.dart                 # faEn / enDe / enDeVerbs / visual
│   ├── language_code.dart              # en / fa / de (+ direction getter)
│   └── level_direction.dart            # up / down
├── repository/
│   ├── card_repository.dart            # Hive CRUD for 'card' box
│   └── progress_repository.dart       # Hive CRUD for 'progress' box
├── service/
│   ├── card_service.dart               # Leitner algorithm
│   ├── route_service.dart              # pushNamed / pushReplacementNamed wrappers
│   ├── stt_service.dart               # Speech-to-text; reactive isListening, liveText; sttMatches()
│   ├── sync_service.dart               # saveCard / removeCard — all-or-nothing Hive writes
│   ├── theme_service.dart             # Reactive GetX service, persists to Hive 'settings'
│   └── tts_service.dart               # Text-to-speech; reactive isSpeaking, wordStart, wordEnd
├── util/
│   ├── date_time_util.dart             # now(), daysToNowWithoutTime()
│   ├── dialog_util.dart               # error(), ok(), okCancel(), hint()
│   └── list_util.dart                 # sortAsc() / sortDesc()
└── view/
    ├── app_drawer.dart                 # Side nav drawer (gradient header, tiles, theme toggle)
    ├── data_screen.dart               # Card list for a deck (edit / delete)
    ├── download_screen.dart           # Manual download from GitHub (full screen)
    ├── error_screen.dart              # Route error fallback
    ├── home_screen.dart               # Root screen — no AppBar, burger in gradient header
    ├── leitner_screen.dart            # Main study view (FA_EN / EN_DE decks)
    ├── level_screen.dart              # Level picker for a deck
    ├── loading_screen.dart            # Generic spinner screen
    ├── merge_screen.dart              # Edit card form
    ├── persist_screen.dart            # Add card form
    ├── stats_screen.dart              # Per-deck stats with TabBar
    └── widget/
        ├── animated_button.dart       # AnimatedButton(isActive, activeColor)
        ├── animated_flag.dart         # AnimatedFlag — floating country flag
        ├── animated_gradient_background.dart  # AMOLED-adaptive card background
        ├── description_sheet.dart     # DescriptionSheet.show() — draggable bottom sheet
        └── icon_button_widget.dart    # Styled icon button
```

---

## 5 · Routes

Initial route is `"/"` → `HomeScreen` (no startup download).

| Constant | Path | Screen | Required args |
|---|---|---|---|
| `RouteConfig.home` | `/` | `HomeScreen` | — |
| `RouteConfig.visualLeitner` | `/visual-leitner` | `VisualLeitnerScreen` | `level: int` |
| `RouteConfig.level` | `/level` | `LevelScreen` | `groupCode: GroupCode` |
| `RouteConfig.data` | `/data` | `DataScreen` | `groupCode: GroupCode` |
| `RouteConfig.leitner` | `/leitner` | `LeitnerScreen` | `groupCode: GroupCode`, `level: int` |
| `RouteConfig.persist` | `/persist` | `PersistScreen` | `groupCode: GroupCode` |
| `RouteConfig.merge` | `/merge` | `MergeScreen` | `cardEntity: CardEntity` |
| `RouteConfig.download` | `/download` | `DownloadScreen` | — |
| `RouteConfig.stats` | `/stats` | `StatsScreen` | — |
| `RouteConfig.loading` | `/loading` | `LoadingScreen` | — |

All navigation uses `Get.find<RouteService>().pushNamed()` or `pushReplacementNamed()`.

---

## 6 · GetX Dependency Injection

Registration order in `DependencyConfig.registerDependencies()` is **critical**:

```
1. ThemeService.init()      ← async; must be first — MyApp reads mode synchronously
2. RouteService()           ← provides navigatorKey for MaterialApp
3. CardRepository()         ← opens 'card' Hive box
4. ProgressRepository()     ← opens 'progress' Hive box
5. CardService()            ← depends on both repositories
6. SyncService()            ← depends on CardRepository
7. TtsService()             ← no dependencies; registers flutter_tts handlers
8. SttService()             ← speech-to-text; skips init on macOS (TCC crash)
```

Usage everywhere: `Get.find<ServiceName>().method()`.

---

## 7 · Entity Layer

### CardEntity — Hive typeId: 1, box: `'card'`

| Field | HiveField | Type | Notes |
|---|---|---|---|
| `id` | 0 | `int` | Epoch seconds: `DateTime.now().millisecondsSinceEpoch ~/ 1000` |
| `created` | 1 | `tz.TZDateTime` | Set on creation, never changed |
| `modified` | 2 | `tz.TZDateTime` | Updated on content change |
| `groupCode` | 3 | `String` | `"FA_EN"`, `"EN_DE"`, `"EN_DE_VERBS"`, or `"VISUAL"` |
| `image` | 4 | `String` | Filename (Visual deck) or `""` |
| `en` | 5 | `String` | English text |
| `fa` | 6 | `String` | Farsi text |
| `de` | 7 | `String` | Deutsch text |
| `desc` | 8 | `String` | Description / hint |

Getter: `GroupCode get group => GroupCode.fromCode(groupCode)`

### ProgressEntity — Hive typeId: 2, box: `'progress'`

| Field | HiveField | Type | Notes |
|---|---|---|---|
| `cardId` | 0 | `int` | FK → CardEntity.id (box key) |
| `level` | 1 | `int` | Current Leitner level. Default: `ProgressEntity.initLevel` = 0 |
| `subLevel` | 2 | `int` | Sub-gating counter. Default: `ProgressEntity.initSubLevel` = 1 |
| `order` | 3 | `int` | Study visit counter (for within-level ordering) |
| `created` | 4 | `tz.TZDateTime` | — |
| `modified` | 5 | `tz.TZDateTime` | Last time level/subLevel changed |

### ⚠️ Hive Adapter Warning
`card_entity.g.dart` and `progress_entity.g.dart` reference `HiveTypeIds.cardId` / `HiveTypeIds.progressId` by name. **Never run `flutter pub run build_runner build`** — it would overwrite these with hardcoded integers. Re-apply manually if ever needed.

---

## 8 · Repository Layer

### CardRepository — box: `'card'`

| Method | Signature | Notes |
|---|---|---|
| `listenable()` | `ValueListenable<Box<CardEntity>>` | For `ValueListenableBuilder` |
| `merge()` | `Future<void> merge(CardEntity)` | Upsert by `card.id` |
| `remove()` | `Future<void> remove(CardEntity)` | — |
| `removeAll()` | `Future<void>` | Deletes all keys |
| `removeList()` | `Future<void> removeList(List<CardEntity>)` | Parallel delete |
| `findById()` | `CardEntity? findById(int id)` | Nullable |
| `findAll()` | `List<CardEntity>` | — |
| `findAllByGroupCode()` | `List<CardEntity> findAllByGroupCode(GroupCode)` | Filters by `groupCode` string |
| `findAllGroupCodeBased()` | `Map<String, int>` | Count per groupCode — for StatsScreen |

### ProgressRepository — box: `'progress'`

| Method | Signature | Notes |
|---|---|---|
| `merge()` | `Future<void> merge(ProgressEntity)` | Upsert by `progress.cardId` |
| `findByCardId()` | `ProgressEntity? findByCardId(int)` | Nullable |
| `findOrCreate()` | `ProgressEntity findOrCreate(int cardId)` | Returns existing or default (NOT persisted) |
| `findAll()` | `List<ProgressEntity>` | — |
| `removeAll()` | `Future<void>` | — |
| `exportAll()` | `List<Map<String, dynamic>>` | JSON-serializable snapshot for export |

---

## 9 · Service Layer

### CardService
`findAllBasedOnLeitner(GroupCode) → List<(CardEntity, ProgressEntity)>`

**Leitner Algorithm:**
1. Load all cards for deck
2. Build `Map<cardId, ProgressEntity>` via `findOrCreate`
3. Group cards by level → `Map<int, List<CardEntity>>`
4. Sort level keys **descending**
5. Per level:
   - **Level 0:** Always due — add all cards
   - **Level N > 0:** `maxSubLevelCount = 2^(N-1)`
     - `daysToNowWithoutTime(progress.modified) >= 1`?
       - If `subLevel < maxSubLevelCount`: increment subLevel, persist, **skip**
       - If `subLevel >= maxSubLevelCount`: **due — add**
     - Else (modified today): **skip**
6. Sort each level group by `progress.order` ascending
7. Return flattened list

### SyncService
All-or-nothing Hive writes. Never write directly to Hive from views.

| Method | Purpose |
|---|---|
| `saveCard(CardEntity)` | Upsert card content to Hive |
| `removeCard(CardEntity)` | Delete one card from Hive |
| `removeCards(List<CardEntity>)` | Delete multiple cards from Hive |

> ⚠️ Auto-download on startup was removed. Downloads happen only via `DownloadScreen` (triggered manually from `AppDrawer`).

### ThemeService
- Hive box: `'settings'`, key: `'themeMode'`
- `mode` → `ThemeMode` (reactive `Obs`)
- `toggle()` → cycles `system → light → dark → system`
- `setMode(ThemeMode)` → persists to Hive
- `icon` / `label` getters for UI

### TtsService
- `speak(text, LanguageCode)` → `Future<bool>` — returns `false` if language engine not installed
- `stop()` — stops playback immediately
- Reactive: `isSpeaking`, `wordStart`, `wordEnd` — drive word highlight in `LeitnerScreen`
- Locale map: `en → en-US`, `fa → fa-IR`, `de → de-DE`
- Speech rate: `0.45` (slightly slower for language learning)
- Requires Google TTS engine for Farsi and word-boundary progress events

### SttService
- `listen(LanguageCode)` → `Future<String?>` — starts mic, returns recognised text or `null`
- `stop()` — stops listening immediately
- Reactive: `isListening` (`RxBool`), `liveText` (`RxString`) — drive pulsing mic button in AppBar
- Uses `ListenMode.confirmation` (not dictation — crashes on Samsung and some OEMs)
- `pauseFor: 2s` — auto-stops after 2s of silence; reacts fast to both short and long utterances
- `cancelOnError: true` — cleans up on error
- Skips `initialize()` entirely on macOS (TCC SIGABRT before Dart catch)
- `sttMatches(recognised, expected, {threshold: 0.75})` — top-level fuzzy comparator:
  normalises both strings, checks ≥75% of expected words appear in recognised text

### RouteService
- Holds `GlobalKey<NavigatorState> navigatorKey`
- `pushNamed(route, {arguments})` → `Future`
- `pushReplacementNamed(route, {arguments})` → replaces current

---

## 10 · Enums

### GroupCode
```dart
enum GroupCode { faEn('FA_EN'), enDe('EN_DE'), enDeVerbs('EN_DE_VERBS'), visual('VISUAL') }
// .code → stored string
// .title → 'English' | 'Deutsch' | 'Verbs' | 'Visual'
// GroupCode.fromCode(String?) → defaults to faEn if unrecognised
```

### LanguageCode
```dart
enum LanguageCode { en, fa, de }
// .direction → TextDirection.rtl (fa) | TextDirection.ltr (en, de)
```

### LevelDirection
```dart
enum LevelDirection { up, down }
```

---

## 11 · Design System

### Theme
- Seed colour: `Color(0xFF3D5A80)` — muted steel-blue
- Material 3, `ColorScheme.fromSeed`
- `AppTheme.toolbarHeight = 64`
- `AppBarTheme.actionsPadding = EdgeInsets.only(right: 12)`

### Dark Mode Tokens (always use, never hardcode)
| Use | Token |
|---|---|
| Card background | `colorScheme.surface` |
| Elevated surface | `colorScheme.surfaceContainerHighest` |
| Secondary text | `colorScheme.onSurfaceVariant` |
| Borders | `colorScheme.outlineVariant` |

### AppBar convention
```dart
AppBar(backgroundColor: _accentColor, foregroundColor: Colors.white, elevation: 0)
```

### Deck accent colours
| Deck | Accent | Gradient |
|---|---|---|
| FA_EN (English) | `Colors.blue.shade600` | `[Color(0xFF1565C0), Color(0xFF42A5F5)]` |
| EN_DE (Deutsch) | `Colors.orange.shade700` | `[Color(0xFFE65100), Color(0xFFFFB74D)]` |
| Visual | `Colors.teal.shade600` | — |

### Level colours (16-step palette)
```dart
Color _levelColor(int level) {
  const colors = [
    Color(0xFFF44336), Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFFFC107),
    Color(0xFFFFEB3B), Color(0xFFCDDC39), Color(0xFF8BC34A), Color(0xFF4CAF50),
    Color(0xFF009688), Color(0xFF00BCD4), Color(0xFF03A9F4), Color(0xFF2196F3),
    Color(0xFF3F51B5), Color(0xFF673AB7), Color(0xFF9C27B0), Color(0xFFE91E63),
  ];
  return colors[level.clamp(0, colors.length - 1)];
}
```

### Level icons (weakest → strongest animal)
```
0:🐛  1:🐌  2:🐁  3:🐇  4:🦔  5:🦊  6:🐺  7:🐗
8:🐆  9:🦁  10:🐯  11:🦅  12:🦈  13:🦏  14:🐘  15:🐉
```

### Cards / containers
- Large radius: `BorderRadius.circular(14)` | Form fields: `12`
- Shadow: `BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))`

### AnimatedGradientBackground
- **Dark:** `#0D1B2A → #152232 → #1A2B3C → #0F1923` (midnight navy, AMOLED-friendly)
- **Light:** `#E8EDF2 → #D6DFE8 → #CDD8E3 → #D8E3EC` (cool silver-white)
- 12-second animation loop

### API deprecations
Always `.withValues(alpha: x)` — never `.withOpacity(x)` (deprecated Flutter 3.x).

---

## 12 · Screen Reference

### HomeScreen
- Initial route `/` — no AppBar
- Burger menu lives inside gradient header; body wrapped in `Builder` for `Scaffold.of()`
- Three deck cards + Visual card → navigate to `LevelScreen` or `VisualLeitnerScreen`

### LevelScreen
- Shows all levels that have cards, sorted; colour + emoji badge per level
- "Play All" FAB (`allLevel = -1`): runs full Leitner algorithm; STT grades cards (thumbs-up)
- "Play Limited" AppBar icon (`allLimitedLevel = -2`): all cards, ignores schedule; STT just advances
- Per-level play (level number ≥ 0): only cards at that level; STT just advances, no grading
- All navigation to `LeitnerScreen` uses `pushNamed` (not `pushReplacementNamed`) so back returns here
- `LeitnerScreen.allLevel = -1`, `LeitnerScreen.allLimitedLevel = -2` constants

### LeitnerScreen
- Study view for FA_EN / EN_DE / EN_DE_VERBS decks
- AppBar title: `X / Y` counter (left-aligned, small font)
- **AMOLED burn-in protection:**
  - Pixel shifting: `Timer.periodic(30s)` shifts ±2px via `Transform.translate`
  - Auto-dim: after 2 min idle → `Colors.black` overlay alpha 0.85. Tap to wake.
  - `Listener(onPointerDown:)` resets idle timer
- AppBar actions: 🔊 speak + copy + 🎤 mic
- 🔊 Speak button reads current card text via `TtsService`; icon toggles stop/speak while active
- Word highlight: `Text.rich` with background colour span driven by `TtsService.wordStart/wordEnd`
- TTS stops on page swipe, language flip, and screen dispose
- Thumb buttons: `AnimatedButton(isActive, activeColor)` — green (up) / redAccent (down)
- Description button → `DescriptionSheet.show()`
- **Session complete dialog** shown at end of deck — "Stay" or "Done" (never auto-closes)
- **STT mic button** (🎤): pulses red while listening; `SttService` auto-stops on silence (2s)
  - Language always targets the learning language: FA_EN → EN, EN_DE/EN_DE_VERBS → DE
  - Play All (`allLevel`): correct → thumbs-up + advance; auto-restarts for next card
  - Play Limited / per-level: correct → advance only, no level change; auto-restarts
  - Wrong → snackbar showing what was said vs expected
  - Uses `ListenMode.confirmation` (not dictation — crashes on Samsung)

### VisualLeitnerScreen
- Image URL: `https://raw.githubusercontent.com/akz792000/Dictionary/main/images/{image}`
- Same AMOLED burn-in protection as LeitnerScreen
- Per-card language tab state: `Map<int, int> _langTabMap` (0=en, 1=de)
- Revealed state: `Set<int> _revealedSet` — thumbs disabled until card tapped/revealed

### DataScreen
- Card list for a deck; tap → `MergeScreen`; FAB → `PersistScreen`
- Delete per-card or delete-all (confirmation dialog)
- RTL secondary text for FA_EN, LTR for EN_DE/VISUAL

### DownloadScreen
- Full-screen (not a modal). Navigate via `RouteConfig.download`.
- Downloads `fa_en.json`, `en_de.json`, `en_de_verbs.json`, `visual.json` from GitHub
- Base URL: `https://raw.githubusercontent.com/akz792000/Dictionary/main`
- "Override" toggle per deck: ON resets progress to level 0 + subLevel 1 on download

### PersistScreen
- ID: `DateTime.now().millisecondsSinceEpoch ~/ 1000`
- Fields shown by groupCode: FA_EN → fa+en, EN_DE → en+de, VISUAL → en+de+image

### MergeScreen
- Shows read-only metadata chips (id, created, level, subLevel, order, modified)
- All text fields editable; on save: calls `SyncService.saveCard()`

### StatsScreen
- TabBar: one tab per `GroupCode` value
- Metrics: total, started, totalReviews, maxLevel, levelMap, reviewedToday, lastModified

### AppDrawer
- Gradient profile header with `image.png`
- Nav tiles: English deck, Deutsch deck, Visual deck, Sync Cards (→ DownloadScreen), Stats
- Theme toggle tile (Obx-wrapped): cycles system/light/dark
- About dialog at bottom

---

## 13 · Widget Reference

### AnimatedButton
```dart
AnimatedButton({required bool isActive, required Color activeColor, required VoidCallback onPressed, required Widget child})
```
Breathing scale+float animation (3s loop, scale 1.0→1.12).

### AnimatedFlag
```dart
AnimatedFlag({required GroupCode groupCode})
```
Floating flag animation (3s loop).

### AnimatedGradientBackground
```dart
AnimatedGradientBackground({required Widget child})
```
12s gradient animation. Adapts dark/light automatically.

### DescriptionSheet
```dart
DescriptionSheet.show(BuildContext context, String description)
```
Draggable modal bottom sheet.

### IconButtonWidget
```dart
IconButtonWidget({required IconData icon, required VoidCallback onTap, Color? color})
```

---

## 14 · Utility Reference

### DateTimeUtil
- `now()` → `tz.TZDateTime` (local timezone)
- `daysToNowWithoutTime(tz.TZDateTime)` → `int` — midnight-to-midnight day diff (drives Leitner scheduling)

### DialogUtil
- `error(context, {title, description})`
- `ok(context, {title, description})`
- `okCancel(context, {title, description, onOk})`
- `hint(context, {title, description})`

### ListUtil
- `sortAsc(List)` → sorted in place
- `sortDesc(List)` → sorted in place

### ColorUtil
- Gradient creation helpers

---

## 15 · Android

- `applicationId = "com.flashmind.app"`
- Kotlin folder: `android/app/src/main/kotlin/com/flashmind/app/MainActivity.kt`
- Permissions in `AndroidManifest.xml`: `INTERNET` (downloads/images), `RECORD_AUDIO` + `BLUETOOTH` (STT)
- Java/Kotlin targets: `VERSION_11`
- Toolchain versions: Gradle `8.14`, AGP `8.11.1`, Kotlin `2.2.20`
- `kotlin-android` plugin removed from `app/build.gradle.kts` — Flutter's built-in Kotlin handles it
- **Zscaler SSL fix** in `android/gradle.properties`:
  ```properties
  org.gradle.jvmargs=... -Djavax.net.ssl.trustStoreType=KeychainStore
  ```
- **iOS Simulator SSL** `CERTIFICATE_VERIFY_FAILED` → `_DevHttpOverrides` in `main.dart` (debug only, `kDebugMode` guard)

---

## 16 · Wireless ADB (Samsung A52)

Two separate steps — ports are always different:
1. `adb pair <IP:PAIRING_PORT>` — short-lived port from "Pair device with pairing code" dialog
2. `adb connect <IP:MAIN_PORT>` — persistent port from main "Wireless debugging" screen

See `docs/android-device-debugging-guide.md` for full steps.

---

## 17 · Workflow Conventions

1. **🚨 NEVER commit or push without the user explicitly saying "commit" or "push". No exceptions.**
2. **After every code change:** update `.github/copilot-instructions.md` to reflect the change — new routes, new services, removed features, changed behaviour, new gotchas. The instructions must always match the actual code.
3. **Before every commit (only when user asks):** run `dart format lib/` first, then `flutter analyze lib/` — zero errors before committing. A pre-commit hook already runs `dart format` automatically.
4. Dark mode must work on all screens — use design tokens, never hardcode colours.
4. All new routes go in `route_config.dart` (constant + switch case).
5. All new GetX services go in `dependency_config.dart` in correct dependency order.
6. File names: `snake_case.dart`. Screen classes: `*Screen`. Widgets: descriptive names.
7. Never write directly to Hive from views — always go through `SyncService`.
8. **Keep comments up to date with every code change.**
   - Classes: doc comment explaining purpose and key design decisions.
   - Methods: comment if the *why* is not obvious from the name alone.
   - Fields: inline comment when the meaning or constraint isn't self-evident.
   - Do NOT comment obvious one-liners.
   - When modifying code, update or remove stale comments in the same change.

---

## 18 · Known Issues / Gotchas

| Issue | Detail |
|---|---|
| Hive adapters | `card_entity.g.dart` and `progress_entity.g.dart` are manually maintained. **Do NOT run build_runner.** |
| Max Hive key | `0xFFFFFFFF`. Use seconds epoch for IDs: `DateTime.now().millisecondsSinceEpoch ~/ 1000` |
| iOS exit button | Removed — iOS HIG discourages quit buttons. Do not add back. |
| Hive box `'settings'` | Opened by `ThemeService.init()` — not by Hive setup in `main.dart`. |
| Hive schema corruption | `_openBoxSafe<T>()` in `main.dart` catches corrupt box errors, deletes and recreates fresh. User must re-download cards. |
| STT on macOS | `speech_to_text.initialize()` causes OS-level TCC SIGABRT on macOS before Dart try-catch runs. Fix: skip STT init entirely when `defaultTargetPlatform == TargetPlatform.macOS`. |
| STT on Samsung | `ListenMode.dictation` crashes on Samsung/some Android OEMs when speech is first detected. Always use `ListenMode.confirmation`. |
| STT on iOS Simulator | Simulator doesn't support speech recognition. `listen()` throws `ListenFailedException`. Wrapped in try-catch; mic button is silently disabled. |
| KGP build warnings | `flutter_tts` and `speech_to_text` apply `kotlin-android` in their own `build.gradle`. Patched in pub cache — see `docs/known-issues-and-fixes.md`. `deploy.sh` uses `--android-skip-build-dependency-validation` as fallback. |
| `sync_screen.dart` | Orphaned file (no-op stub). Not used in any route. Keep for history. |

---

## 20 · Deploying to Phone

**Quickest method** (phone already connected via ADB):
```bash
flutter run --release
```
Builds + installs in one command. No manual file transfer.

**Using the deploy script:**
```bash
./deploy.sh                # build release + install (phone already connected)
./deploy.sh --clean        # flutter clean first, then build + install
./deploy.sh --connect      # prompts for wireless ADB address first, then builds + installs
./deploy.sh --backup       # back up Hive data before install, restore after (prevents data loss)
```

**Wireless ADB connect steps** (when not already connected):
1. On phone: Settings → Developer options → Wireless debugging → ON
2. `adb pair <IP:PAIRING_PORT>` — port from "Pair device with pairing code" dialog
3. `adb connect <IP:MAIN_PORT>` — port from main "Wireless debugging" screen
4. Then run `./deploy.sh` or `flutter run --release`

See `docs/android-device-debugging-guide.md` for full steps.

- `docs/android-device-debugging-guide.md` — wireless ADB + ClassNotFoundException fix
- `docs/known-issues-and-fixes.md` — Gradle SSL, JVM symlink, Android Studio issues
