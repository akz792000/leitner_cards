# Copilot Instructions — Leitner Cards

This file is the single source of truth for GitHub Copilot (and future AI sessions) working on this project.
Read this before making any changes.

> 🚨 **NEVER commit or push without the user explicitly asking. This is a hard rule — no exceptions.**

---

## Project Overview

**Leitner Cards** is a Flutter flashcard app implementing the Leitner spaced repetition system.
Users study cards that move to higher levels when answered correctly and drop back when wrong,
optimising review frequency. Two language decks are supported:

- **English ↔ Farsi** (`GroupCode.english`, `group_code: 0`)
- **Deutsch ↔ English** (`GroupCode.deutsch`, `group_code: 1`)

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.35.6 / Dart 3.9.2 |
| State management | GetX (`get` package) |
| Local storage | Hive |
| Remote storage | Supabase (PostgreSQL) |
| Navigation | GetX named routes (custom `RouteService`) |
| Theming | Material 3, `ColorScheme.fromSeed` |
| Date/timezone | `intl` + `timezone` package |

---

## Repository & Git

- **GitHub account:** `akz792000`
- **Remote:** `git@github.personal.com:akz792000/leitner_cards.git`
  - Uses SSH alias `github.personal.com` → maps to key `~/.ssh/id_rsa`
  - The other account `KarimizandiA` uses `github.com` → `~/.ssh/id_ed25519`
- **Branch:** `main`
- **⚠️ Do NOT commit or push unless the user explicitly says so.**

---

## Supabase

- **URL:** `https://utjodpuzeytossfezaol.supabase.co`
- **Key:** loaded from `.env` via `flutter_dotenv` (never hardcode)
- **Tables:**
  - `cards` — card content (id, en, fa, de, description, group_code, modified)
  - `progress` — per-card level/sublevel/order (synced separately)
- **RLS:** Row Level Security is **disabled** — this is intentional for a single-user personal app
- **Sync:** Bidirectional on startup via `SyncService.syncOnStartup()`. Remote wins if `modified` timestamp is newer.

### Inserting cards via curl

```bash
BASE_URL="https://utjodpuzeytossfezaol.supabase.co"
KEY="<anon key from .env>"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BASE_ID=$(date +%s)

curl -s -X POST "$BASE_URL/rest/v1/cards" \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "[{\"id\": $((BASE_ID+1)), \"en\": \"apple\", \"fa\": \"سیب\", \"de\": \"\", \"description\": \"\", \"group_code\": 0, \"modified\": \"$NOW\"}]"
```

---

## Architecture

```
lib/
├── config/
│   ├── AppTheme.dart          # Light + dark ThemeData (Material 3)
│   ├── DependencyConfig.dart  # GetX DI — ThemeService MUST be first
│   └── RouteConfig.dart       # All route constants + switch
├── entity/
│   ├── CardEntity.dart        # Hive model — @HiveType(typeId: HiveTypeIds.cardId)
│   ├── CardEntity.g.dart      # ⚠️ Manually patched — uses HiveTypeIds.cardId by name
│   └── HiveTypeIds.dart       # cardId = 0 (was CARD_ID — renamed)
├── enums/
│   ├── GroupCode.dart         # english / deutsch — has .title getter
│   ├── LanguageCode.dart      # en / fa / de — has .direction getter (TextDirection)
│   └── LevelDirection.dart    # up / down (replaces old 'UP'/'DOWN' strings)
├── model/
│   └── OptionModel.dart       # image: Widget, onTap: VoidCallback?
├── repository/
│   └── CardRepository.dart    # Hive CRUD — findAllByGroupCode, findAllLevelBasedByGroupCode
├── service/
│   ├── DependencyConfig.dart  # (see config/)
│   ├── RouteService.dart      # pushNamed / pushReplacementNamed wrappers
│   ├── SyncService.dart       # saveCard / removeCard / removeCards — all-or-nothing (Hive+Supabase)
│   └── ThemeService.dart      # GetX service, persists theme to Hive 'settings' box
├── util/
│   ├── DateTimeUtil.dart
│   ├── DialogUtil.dart
│   └── ListUtil.dart          # sortAsc / sortDesc — comparators were inverted, now fixed
└── view/
    ├── HomeView.dart          # StatelessWidget — gradient header, language cards, tool cards
    ├── LevelView.dart         # Level picker — coloured header, level cards with left border
    ├── DataView.dart          # Card list — en+fa/de rows, level badge, empty state
    ├── PersistView.dart       # Add card form — OutlinedInputBorder, FilledButton
    ├── MergeView.dart         # Edit card form — same as Persist + metadata chip section
    ├── DownloadView.dart      # Sync from Supabase — deck toggle cards, FilledButton
    ├── LeitnerView.dart       # Flashcard study — AnimatedSwitcher flip, page depth effect
    ├── StatsView.dart         # Statistics — tabs per language, summary cards, level bars
    ├── SyncView.dart          # Startup sync screen
    ├── DrawerWidgetView.dart  # Drawer — theme toggle tile (Obx)
    ├── LoadingView.dart
    └── ErrorView.dart
```

---

## Design System

All screens share the same visual language. **Follow these rules strictly:**

### Colours
| Context | Colour |
|---|---|
| English accent | `Colors.blue.shade600` |
| Deutsch accent | `Colors.orange.shade700` |
| English gradient | `[Color(0xFF1565C0), Color(0xFF42A5F5)]` |
| Deutsch gradient | `[Color(0xFFE65100), Color(0xFFFFB74D)]` |

**Level colours — each level has its own unique colour. Use this exact palette everywhere (LevelView, DataView, StatsView):**
```dart
Color _levelColor(int level) {
  const colors = [
    Color(0xFFF44336), // 0  red
    Color(0xFFFF5722), // 1  deep orange
    Color(0xFFFF9800), // 2  orange
    Color(0xFFFFC107), // 3  amber
    Color(0xFFFFEB3B), // 4  yellow
    Color(0xFFCDDC39), // 5  lime
    Color(0xFF8BC34A), // 6  light green
    Color(0xFF4CAF50), // 7  green
    Color(0xFF009688), // 8  teal
    Color(0xFF00BCD4), // 9  cyan
    Color(0xFF03A9F4), // 10 light blue
    Color(0xFF2196F3), // 11 blue
    Color(0xFF3F51B5), // 12 indigo
    Color(0xFF673AB7), // 13 deep purple
    Color(0xFF9C27B0), // 14 purple
    Color(0xFFE91E63), // 15 pink
  ];
  return colors[level.clamp(0, colors.length - 1)];
}
```
Never group levels into tiers sharing a colour — every level must be visually distinct.

### AppBar
```dart
AppBar(
  backgroundColor: _accentColor,  // blue or orange
  foregroundColor: Colors.white,
  iconTheme: const IconThemeData(color: Colors.white),
  elevation: 0,
)
```

### Cards / containers
- `BorderRadius.circular(14)` for large cards, `12` for form fields
- `boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]`
- Background: `Theme.of(context).colorScheme.surface`
- Borders: `Theme.of(context).colorScheme.outlineVariant`

### Form fields
```dart
InputDecoration(
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: _accentColor, width: 2),
  ),
  prefixIcon: Icon(icon, color: _accentColor),
)
```

### Primary button
```dart
FilledButton.icon(
  style: FilledButton.styleFrom(
    backgroundColor: _accentColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
)
```

### Section labels
```dart
Text('SECTION TITLE', style: TextStyle(
  fontSize: 11, fontWeight: FontWeight.bold,
  letterSpacing: 1, color: Theme.of(context).colorScheme.onSurfaceVariant,
))
```

### Dark mode tokens
Always use these — never hardcode white/black for backgrounds or text:
- Card background → `colorScheme.surface`
- Elevated surface → `colorScheme.surfaceContainerHighest`
- Secondary text → `colorScheme.onSurfaceVariant`
- Borders → `colorScheme.outlineVariant`

---

## Key Rules & Gotchas

### Hive IDs
- Max Hive key: `0xFFFFFFFF` (~4.3 billion)
- `DateTime.now().millisecondsSinceEpoch` **overflows** this — always use `~/ 1000` (seconds epoch)
- `CardEntity.g.dart` is NOT purely generated — it references `HiveTypeIds.cardId` by name.
  Re-running `build_runner` will **overwrite** it and break the rename. Re-apply manually if needed.

### SyncService — all-or-nothing
`saveCard`, `removeCard`, `removeCards` write to **both** Hive and Supabase.
If either fails the other is rolled back. Never write to Hive or Supabase directly from views.

### ThemeService must be registered first
`DependencyConfig` registers `ThemeService` before all other services because
`MyApp.build()` calls `Get.find<ThemeService>()` before the widget tree renders.

### LevelDirection enum
`LevelDirection.up` / `LevelDirection.down` — replaces old magic strings `'UP'`/`'DOWN'`.
UI state (`_levelChangedMap`, `_orderChangedSet`) lives in `_LeitnerViewState`, NOT on `CardEntity`.

### File naming
All Dart files use `PascalCase` (e.g. `CardEntity.dart`). This triggers 35+ `info`-level
`file_names` warnings from the linter — this is **expected and intentional**. Do not rename files.

### iOS Simulator SSL certificate error
`CERTIFICATE_VERIFY_FAILED: application verification failure` when calling Supabase from iOS Simulator.
**Cause:** Dart's BoringSSL cannot verify Supabase's certificate chain in the simulator environment.
**Fix (already applied in `main.dart`):**
```dart
if (kDebugMode) HttpOverrides.global = _DevHttpOverrides();
// _DevHttpOverrides sets badCertificateCallback = true — debug only, no effect in release
```
This is safe — `kDebugMode` is `false` in release builds, so production users are never affected.

### iOS exit
The exit/quit button was **removed** from the drawer. iOS HIG discourages quit buttons; `SystemNavigator.pop()` was unreliable. Do not add it back.

### HomeView — no AppBar
`HomeView` has **no `appBar`** on its `Scaffold`. The burger menu (hamburger `IconButton`) lives inside the gradient hero header widget (`_buildHeader(BuildContext context)`). The `body` is wrapped in a `Builder` to provide a descendant `context` for `Scaffold.of()` (needed to open the drawer).

### Drawer design
`DrawerWidgetView` is a full redesign:
- Gradient header with avatar, name, subtitle
- Navigation tiles: English, Deutsch, Statistics, Sync
- Settings tiles: Theme toggle (Obx), About
- Version footer with safe-area padding
Do not simplify it back to a plain `ListView`.

### Level list order
`LevelView` sorts levels **ascending** (0, 1, 2 …) before building the list:
```dart
final levels = _levelMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
```

### Level icons
Each level uses an **emoji** inside a coloured circle badge (+ number badge in corner). PNG assets are no longer used. Emoji progression (0–15):
```
0:🥚  1:🐣  2:🐥  3:🌱  4:🌿  5:🌳  6:⚡  7:🔥
8:💡  9:🎯  10:⭐  11:🌟  12:💫  13:🏆  14:👑  15:💎
```

### `win32` package
Stuck at v5 because `win32 ^6.x` requires Dart ≥ 3.10.0 (current: 3.9.2). Do not upgrade.

### Zscaler (corporate proxy) SSL error during `flutter build apk`
**Error:** `SSLHandshakeException: PKIX path building failed`
**Cause:** Gradle's JVM doesn't use the macOS Keychain, so it can't see the Zscaler root cert.
**Fix (already in `android/gradle.properties`):**
```properties
org.gradle.jvmargs=... -Djavax.net.ssl.trustStoreType=KeychainStore
```
This makes Gradle's JVM use the macOS Keychain where Zscaler's cert is already installed. No need to stop Zscaler.

---

## Hot Reload Reference

| Action | Shortcut (Mac) | When to use |
|---|---|---|
| Hot Reload ⚡ | `⌘ + \` | UI/logic changes — keeps state |
| Hot Restart 🔄 | `⇧ + ⌘ + \` | New variables, `initState` changes |
| Full Restart ▶️ | Stop + Run | New packages, native config |

---

## Workflow Conventions

1. **Never commit or push without explicit user instruction.**
2. Run `flutter analyze` after every change. Zero errors required before asking to commit.
3. Dark mode must work on all new screens — use design tokens, never hardcode colours.
4. Keep `CardEntity.g.dart` in sync if `HiveTypeIds` changes — `build_runner` will overwrite it.
5. All new routes go in `RouteConfig` (constant + switch case).
6. All new GetX services go in `DependencyConfig.dart`.
