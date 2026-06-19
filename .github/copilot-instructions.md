# Copilot Instructions — FlashMind

> 🚨 **NEVER commit or push unless the user explicitly says "commit" or "push". No exceptions.**

---

## 1 · Project

**FlashMind** (`com.flashmind.app`) — Flutter Leitner spaced-repetition flashcard app.  
Cards advance on correct answers, drop to level 0 on wrong answers. Four decks:

| Deck | `GroupCode` | Stored string | Fields |
|---|---|---|---|
| Farsi ↔ English | `faEn` | `"FA_EN"` | `en`, `fa`, `desc` |
| English ↔ Deutsch (sentences) | `enDe` | `"EN_DE"` | `en`, `de`, `desc` |
| English ↔ Deutsch (verbs) | `enDeVerbs` | `"EN_DE_VERBS"` | `en`, `de`, `desc` |
| Visual | `visual` | `"VISUAL"` | `en`, `de`, `image`, `desc` |

Deutsch sub-deck: HomeScreen shows a dialog to choose "Sentences" (`enDe`) or "Verbs" (`enDeVerbs`).

---

## 2 · Git

| | |
|---|---|
| Remote | `git@github.personal.com:akz792000/leitner_cards.git` (SSH alias → `~/.ssh/id_rsa`) |
| Other account | `KarimizandiA` → `github.com` → `~/.ssh/id_ed25519` |
| Branch | `main` |

---

## 3 · Tech Stack

| Layer | Package |
|---|---|
| UI | Flutter 3.x / Dart `>=3.3.0 <4.0.0` |
| State / DI | GetX `^4.6.5` |
| Storage | Hive `^2.2.3` + `hive_flutter ^1.1.0` |
| HTTP | `http ^1.2.2` |
| Timezone | `timezone ^0.10.1` + `intl ^0.20.2` |
| TTS | `flutter_tts ^4.2.5` |
| STT | `speech_to_text` (via `SttService`) |
| Spinner | `flutter_spinkit ^5.1.0` |
| Sizing | `sizer ^3.0.5` |

Assets: `assets/icon.png`, `assets/image.png` (drawer avatar), `assets/flags/{en,de,fa}.png`.

---

## 4 · Project Structure

```
lib/
├── main.dart                  # setup() + MyApp
├── config/
│   ├── app_theme.dart         # Light + dark ThemeData, toolbarHeight=64
│   ├── dependency_config.dart # GetX DI registration (order is critical)
│   └── route_config.dart      # Route constants + generateRoute()
├── entity/
│   ├── card_entity.dart / .g.dart       # Hive typeId=1  ⚠️ never run build_runner
│   ├── progress_entity.dart / .g.dart   # Hive typeId=2  ⚠️ never run build_runner
│   └── hive_type_ids.dart               # cardId=1, progressId=2
├── enums/
│   ├── card_order.dart        # highFirst / lowFirst / random
│   ├── group_code.dart        # faEn / enDe / enDeVerbs / visual
│   ├── language_code.dart     # en / fa / de  (+.direction)
│   └── level_direction.dart   # up / down
├── repository/
│   ├── card_repository.dart     # Hive CRUD, box 'card'
│   └── progress_repository.dart # Hive CRUD, box 'progress'
├── service/
│   ├── card_service.dart      # Leitner scheduling algorithm
│   ├── route_service.dart     # navigatorKey, pushNamed wrappers
│   ├── settings_service.dart  # 13 settings + study-time tracking
│   ├── stt_service.dart       # STT — isListening, liveText, sttMatches()
│   ├── sync_service.dart      # All-or-nothing Hive writes (views → here only)
│   ├── theme_service.dart     # ThemeMode, toggle(), persists to Hive
│   └── tts_service.dart       # TTS — isSpeaking, wordStart, wordEnd
├── util/
│   ├── date_time_util.dart    # now(), daysToNowWithoutTime()
│   ├── dialog_util.dart       # error/ok/okCancel/hint
│   └── list_util.dart         # sortAsc/sortDesc
└── view/
    ├── app_drawer.dart
    ├── data_screen.dart
    ├── download_screen.dart
    ├── error_screen.dart
    ├── home_screen.dart
    ├── leitner_screen.dart
    ├── level_screen.dart
    ├── loading_screen.dart
    ├── merge_screen.dart
    ├── persist_screen.dart
    ├── settings_screen.dart
    ├── stats_screen.dart
    └── widget/
        ├── animated_button.dart
        ├── animated_flag.dart
        ├── animated_gradient_background.dart
        ├── description_sheet.dart
        └── icon_button_widget.dart
```

---

## 5 · Routes

All navigation: `Get.find<RouteService>().pushNamed(route, arguments: {...})`.

| Constant | Path | Screen | Args |
|---|---|---|---|
| `home` | `/` | `HomeScreen` | — |
| `level` | `/level` | `LevelScreen` | `groupCode: GroupCode` |
| `leitner` | `/leitner` | `LeitnerScreen` | `groupCode: GroupCode`, `level: int` |
| `data` | `/data` | `DataScreen` | `groupCode: GroupCode` |
| `persist` | `/persist` | `PersistScreen` | `groupCode: GroupCode` |
| `merge` | `/merge` | `MergeScreen` | `cardEntity: CardEntity` |
| `download` | `/download` | `DownloadScreen` | — |
| `stats` | `/stats` | `StatsScreen` | — |
| `settings` | `/settings` | `SettingsScreen` | — |
| `loading` | `/loading` | `LoadingScreen` | — |

---

## 6 · DI Registration Order (critical — do not reorder)

```
1. ThemeService.init()    ← async; opens 'settings' Hive box
2. SettingsService()      ← reuses 'settings' box
3. RouteService()         ← provides navigatorKey
4. CardRepository()       ← opens 'card' box
5. ProgressRepository()   ← opens 'progress' box
6. CardService()          ← depends on 4 + 5
7. SyncService()          ← depends on 4
8. TtsService()
9. SttService()           ← skips init on macOS (TCC crash)
```

---

## 7 · Entities

### CardEntity — typeId 1, box `'card'`
| HiveField | Name | Type | Notes |
|---|---|---|---|
| 0 | `id` | `int` | `millisecondsSinceEpoch ~/ 1000` |
| 1 | `created` | `TZDateTime` | set once |
| 2 | `modified` | `TZDateTime` | updated on content change |
| 3 | `groupCode` | `String` | `"FA_EN"` / `"EN_DE"` / `"EN_DE_VERBS"` / `"VISUAL"` |
| 4 | `image` | `String` | filename or `""` |
| 5–7 | `en`, `fa`, `de` | `String` | text fields |
| 8 | `desc` | `String` | hint / description |

Getter: `GroupCode get group => GroupCode.fromCode(groupCode)`

### ProgressEntity — typeId 2, box `'progress'`
| HiveField | Name | Type | Notes |
|---|---|---|---|
| 0 | `cardId` | `int` | FK → CardEntity.id |
| 1 | `level` | `int` | default `initLevel = 0` |
| 2 | `subLevel` | `int` | default `initSubLevel = 1` |
| 3 | `order` | `int` | visit counter, used for ordering |
| 4 | `created` | `TZDateTime` | — |
| 5 | `modified` | `TZDateTime` | last level/subLevel change |

⚠️ `.g.dart` files reference `HiveTypeIds` by name — **never run `build_runner`**.

---

## 8 · Repository API

**CardRepository:** `listenable()`, `merge(card)`, `remove(card)`, `removeAll()`, `removeList(list)`, `findById(id)`, `findAll()`, `findAllByGroupCode(code)`, `findAllGroupCodeBased() → Map<String,int>`

**ProgressRepository:** `merge(p)`, `findByCardId(id)`, `findOrCreate(cardId)` *(not persisted)*, `findAll()`, `removeAll()`, `exportAll() → List<Map>`

---

## 9 · Services

### CardService — Leitner algorithm
`findAllBasedOnLeitner(GroupCode) → List<(CardEntity, ProgressEntity)>`
1. Load cards → build `Map<cardId, ProgressEntity>` via `findOrCreate`
2. Group by level, sort keys **descending**
3. Level 0: always due. Level N: `maxSubLevel = 2^(N-1)`
   - Modified today → skip
   - `subLevel < max` → increment subLevel, persist, skip
   - `subLevel >= max` → **due**
4. Sort each level group by `order` asc → return flattened list

### SyncService *(views must never write Hive directly)*
`saveCard(CardEntity)` · `removeCard(CardEntity)` · `removeCards(List<CardEntity>)`

### SettingsService — box `'settings'`
13 reactive settings persisted via `ever()`:
- **STT:** `micEnabled`, `autoListen`, `sttPauseMs` (ms), `sttThreshold` (0–1), `containsMode`
- **TTS:** `speakEnabled`, `speechRate`, `autoSpeak`
- **Display:** `copyEnabled`, `descEnabled`, `counterVisible`, `amoledDim`, `dimDelayMin`
- **Study:** `cardOrder` (`CardOrder` — highFirst/lowFirst/random)

Study time: `studyTimeSecs(GroupCode) → int` · `addStudyTime(GroupCode, Duration)` · keys: `studyTime_<code>`  
`resetToDefaults()` — resets 13 settings only (not study time).

### ThemeService — box `'settings'`, key `'themeMode'`
`toggle()` cycles system→light→dark→system · `setMode(ThemeMode)` · `mode`, `icon`, `label`

### TtsService
`speak(text, LanguageCode) → Future<bool>` · `stop()`  
Reactive: `isSpeaking`, `wordStart`, `wordEnd` — drives word highlight.  
Locales: `en→en-US`, `fa→fa-IR`, `de→de-DE`. Rate: `0.45`.

### SttService
`listen(LanguageCode) → Future<String?>` · `stop()`  
Reactive: `isListening` (RxBool), `liveText` (RxString).  
Always `ListenMode.confirmation` (dictation crashes Samsung). `pauseFor: 2s`. Skips init on macOS.  
`sttMatches(recognised, expected, {threshold=0.75, containsMode=false})` — if `containsMode=true`, first accepts via substring check (`recognised.contains(expected)`), then falls back to word-overlap threshold.

### RouteService
`navigatorKey` · `pushNamed(route, {arguments})` · `pushReplacementNamed(route, {arguments})`

---

## 10 · Enums

```dart
enum GroupCode { faEn('FA_EN'), enDe('EN_DE'), enDeVerbs('EN_DE_VERBS'), visual('VISUAL') }
// .code, .title ('English'|'Deutsch'|'Verbs'|'Visual'), GroupCode.fromCode(String?)

enum LanguageCode { en, fa, de }  // .direction → rtl (fa) | ltr (en, de)

enum LevelDirection { up, down }

enum CardOrder { highFirst, lowFirst, random }
// .code (index), .label, .subtitle, CardOrder.fromCode(int)
```

---

## 11 · Design System

**Theme:** seed `Color(0xFF3D5A80)`, Material 3, `toolbarHeight = 64`, `actionsPadding = EdgeInsets.only(right: 12)`

**Always use tokens — never hardcode colours:**
- surface, surfaceContainerHighest, onSurfaceVariant, outlineVariant
- `AppBar`: `backgroundColor: accentColor, foregroundColor: Colors.white, elevation: 0`
- Always `.withValues(alpha: x)` — never `.withOpacity(x)` (deprecated)

**Deck accent colours:**
- FA_EN: `Colors.blue.shade600` / gradient `[0xFF1565C0, 0xFF42A5F5]`
- EN_DE: `Colors.orange.shade700` / gradient `[0xFFE65100, 0xFFFFB74D]`
- VISUAL: `Colors.teal.shade600`

**Level colours (0→15):** red→deep-orange→orange→amber→yellow→lime→light-green→green→teal→cyan→light-blue→blue→indigo→deep-purple→purple→pink

**Level icons:** `0:🐛 1:🐌 2:🐁 3:🐇 4:🦔 5:🦊 6:🐺 7:🐗 8:🐆 9:🦁 10:🐯 11:🦅 12:🦈 13:🦏 14:🐘 15:🐉`

**Cards:** radius `14` (containers) / `12` (form fields) · shadow `Colors.black12, blur 6, offset (0,2)`

**AnimatedGradientBackground:** dark `#0D1B2A→#152232→#1A2B3C→#0F1923` · light `#E8EDF2→#D6DFE8→#CDD8E3→#D8E3EC` · 12s loop

---

## 12 · Screens

### HomeScreen `/`
No AppBar. Gradient header holds burger menu (`Builder` → `Scaffold.of()`). Body:
- English card → `LevelScreen(faEn)`
- Deutsch card → dialog: Sentences (`enDe`) / Verbs (`enDeVerbs`) → `LevelScreen`
- Visual card → `LevelScreen(visual)`
- Sync Cards tool card → `DownloadScreen`

### LevelScreen `/level`
Level list with colour+emoji badges. `allLevel=-1` (FAB, Play All — Leitner scheduled, STT grades), `allLimitedLevel=-2` (AppBar icon, ignore schedule, STT advances only), per-level ≥0 (STT advances only). Uses `pushNamed` so back returns here.

### LeitnerScreen `/leitner`
Study screen for all decks. Counter `X/Y` in AppBar. AMOLED: pixel shift every 30s ±2px + auto-dim after `dimDelayMin` idle (black overlay 0.85). AppBar: 🔊 TTS + copy + 🎤 STT. Word highlight via `TtsService.wordStart/wordEnd`. Thumb buttons: `AnimatedButton` green/red. Session-complete dialog: Stay/Done.

STT: language = learning lang (FA_EN→EN, EN_DE/VERBS→DE). **Mic button is a toggle** — press once to start continuous loop, press again to stop:
- Loop: listen → evaluate → correct: grade (Play All) or just advance → listen next card; wrong: snackbar + advance without grading → listen next card; nothing heard: retry same card
- `_continuousMode` flag drives the red pulsing animation (`_continuousMode || isListening`)
- `_advancePage()` helper advances the PageView without persisting any level/subLevel changes (used for wrong answers in loop)
- `containsMode`: `sttMatches` first checks if `normalised(recognised).contains(normalised(expected))` as a fast-accept path before the word-overlap threshold check

Study-time: `WidgetsBindingObserver` — pauses on `AppLifecycleState.paused`, resumes on `resumed`, flushes to `SettingsService` on `dispose()`. Foreground only.

### SettingsScreen `/settings`
Sections: STT, TTS, Display, Study. All via `SettingsService` reactively. Reset button → `resetToDefaults()`.

### StatsScreen `/stats`
TabBar per deck. Hero card: time studied (`studyTimeSecs`). Metrics: total, started, totalReviews, maxLevel, level distribution bar chart, reviewedToday, lastModified.

### AppDrawer
Gradient header (image.png, name, "Language Learner"). Tools: Statistics. Settings: Settings, Theme toggle (`Obx`), About dialog. Footer: "Learning Leitner v2.0".

### DataScreen `/data`
Card list. Tap → `MergeScreen`. FAB → `PersistScreen`. Delete single or all. FA_EN → RTL secondary text.

### DownloadScreen `/download`
Downloads `fa_en.json`, `en_de.json`, `en_de_verbs.json`, `visual.json` from `https://raw.githubusercontent.com/akz792000/Dictionary/main`. "Override" toggle resets progress to level 0 + subLevel 1.

### PersistScreen `/persist`
ID = `millisecondsSinceEpoch ~/ 1000`. Fields by deck: FA_EN→fa+en, EN_DE→en+de, VISUAL→en+de+image.

### MergeScreen `/merge`
Read-only chips (id, created, level, subLevel, order, modified). Editable fields. Save → `SyncService.saveCard()`.

---

## 13 · Widgets & Utils

**Widgets:**
- `AnimatedButton(isActive, activeColor, onPressed, child)` — breathing scale+float, 3s loop
- `AnimatedFlag(groupCode)` — floating flag, 3s loop
- `AnimatedGradientBackground(child)` — 12s gradient, auto dark/light
- `DescriptionSheet.show(context, description)` — draggable bottom sheet
- `IconButtonWidget(icon, onTap, color?)` — styled icon button

**Utils:**
- `DateTimeUtil.now()` → `TZDateTime` · `daysToNowWithoutTime(dt)` → `int` (midnight-to-midnight)
- `DialogUtil.error/ok/okCancel/hint(context, {title, description, onOk})`
- `ListUtil.sortAsc/sortDesc(list)` — in place

---

## 14 · Android / Build

- `applicationId = "com.flashmind.app"` · Kotlin `android/app/src/main/kotlin/com/flashmind/app/`
- Permissions: `INTERNET`, `RECORD_AUDIO`, `BLUETOOTH`
- Gradle `8.14`, AGP `8.11.1`, Kotlin `2.2.20`, Java/Kotlin target `VERSION_11`
- `kotlin-android` plugin removed from `app/build.gradle.kts` (Flutter handles it)
- Zscaler SSL fix in `gradle.properties`: `-Djavax.net.ssl.trustStoreType=KeychainStore`
- iOS Simulator SSL: `_DevHttpOverrides` in `main.dart` (debug/`kDebugMode` only)
- ADB wireless (Samsung A52): `adb pair <IP:PAIR_PORT>` then `adb connect <IP:MAIN_PORT>` — always different ports

**Deploy:**
```bash
./deploy.sh               # build + install
./deploy.sh --clean       # flutter clean first
./deploy.sh --connect     # prompt for ADB address first
./deploy.sh --backup      # backup Hive data before install, restore after
flutter run --release     # quickest if already connected
```

---

## 15 · Known Issues

| Issue | Fix / Note |
|---|---|
| Hive adapters `.g.dart` | Manually maintained — **never run `build_runner`** |
| Max Hive key | `0xFFFFFFFF` — use seconds epoch for IDs |
| Hive box `'settings'` | Opened by `ThemeService.init()` only; not in main Hive setup |
| Hive corruption | `_openBoxSafe<T>()` in `main.dart` deletes + recreates; user re-downloads cards |
| STT macOS | TCC SIGABRT before Dart catch — skip `initialize()` when `TargetPlatform.macOS` |
| STT Samsung | `ListenMode.dictation` crashes — always use `ListenMode.confirmation` |
| STT iOS Sim | `ListenFailedException` — wrapped in try-catch, mic silently disabled |
| KGP warnings | `flutter_tts`/`speech_to_text` apply `kotlin-android` in pub cache — see `docs/known-issues-and-fixes.md` |
| `sync_screen.dart` | Orphaned no-op stub — keep for history, not routed |
| iOS quit button | Do not add — against iOS HIG |

---

## 16 · Workflow Conventions

1. 🚨 **Never commit/push without explicit user instruction.**
2. After every code change: update this file to match.
3. Before commit: `dart format lib/` then `flutter analyze lib/` — zero errors.
4. Use design tokens — never hardcode colours.
5. New routes → `route_config.dart` (constant + switch case).
6. New services → `dependency_config.dart` in correct dependency order.
7. File names: `snake_case.dart`. Screens: `*Screen`.
8. Views never write Hive directly — always through `SyncService`.
9. Comments: class doc + method why + field meaning. No obvious one-liners. Keep stale comments updated.
