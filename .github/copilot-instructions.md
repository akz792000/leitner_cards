# Copilot Instructions — Leitner Cards (FlashMind)

This file is the single source of truth for GitHub Copilot (and future AI sessions) working on this project.
Read this before making any changes.

> 🚨 **NEVER commit or push without the user explicitly asking. This is a hard rule — no exceptions.**

---

## Project Overview

**FlashMind** (package: `com.flashmind.app`) is a Flutter flashcard app implementing the Leitner spaced
repetition system. Users study cards that move to higher levels when answered correctly and drop back
when wrong. Three decks:

- **English ↔ Farsi** (`GroupCode.english`, `group_code: 0`)
- **Deutsch ↔ English** (`GroupCode.deutsch`, `group_code: 1`)
- **Visual** — image-based bilingual cards (EN + DE descriptions per image, no groupCode, `VisualCardEntity`)

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.x / Dart 3.x |
| State management | GetX (`get` package) |
| Local storage | Hive |
| Remote storage | Supabase (PostgreSQL) |
| Navigation | GetX named routes (custom `RouteService`) |
| Theming | Material 3, `ColorScheme.fromSeed`, seed `Color(0xFF3D5A80)` |
| Date/timezone | `intl` + `timezone` package |

---

## Repository & Git

- **GitHub account:** `akz792000`
- **Remote:** `git@github.personal.com:akz792000/leitner_cards.git`
  - SSH alias `github.personal.com` → key `~/.ssh/id_rsa`
  - Other account `KarimizandiA` uses `github.com` → `~/.ssh/id_ed25519`
- **Branch:** `main`
- **⚠️ NEVER commit or push unless the user explicitly says so.**

---

## Supabase

- **URL:** `https://utjodpuzeytossfezaol.supabase.co`
- **Key:** loaded from `.env` via `flutter_dotenv` (never hardcode)
- **Tables:**
  - `cards` — card content (id, en, fa, de, description, group_code, modified)
  - `progress` — per-card level/sublevel/order (card_id, level, sub_level, order, modified)
- **RLS:** disabled — intentional for single-user personal app
- **Sync:** Bidirectional on startup via `SyncService.syncOnStartup()`. Remote wins if `modified` newer.
- **Free tier limit:** 500MB — but text-only cards are tiny. Future plan: bundle card content as JSON
  assets, sync only `progress` table to Supabase (saves cloud storage dramatically).

---

## Project Structure

All Dart files use **snake_case** filenames and **Screen** suffix for screen classes (Flutter convention).

```
lib/
├── config/
│   ├── app_theme.dart           # Light + dark ThemeData, seed Color(0xFF3D5A80)
│   ├── dependency_config.dart   # GetX DI — ThemeService MUST be registered first
│   └── route_config.dart        # All route constants + GoRouter switch
├── entity/
│   ├── card_entity.dart         # Hive model — @HiveType(typeId: HiveTypeIds.cardId)
│   ├── card_entity.g.dart       # ⚠️ Manually patched — references HiveTypeIds.cardId by name
│   └── hive_type_ids.dart       # cardId = 0
├── enums/
│   ├── group_code.dart          # english / deutsch — has .title getter
│   ├── language_code.dart       # en / fa / de — has .direction getter (TextDirection)
│   └── level_direction.dart     # up / down
├── models/
│   └── option_model.dart        # image: Widget, onTap: VoidCallback?
├── repository/
│   └── card_repository.dart     # Hive CRUD
├── service/
│   ├── card_service.dart        # Business logic (Leitner algorithm)
│   ├── route_service.dart       # pushNamed / pushReplacementNamed wrappers
│   ├── sync_service.dart        # saveCard / removeCard — all-or-nothing (Hive + Supabase)
│   └── theme_service.dart       # GetX service, persists theme to Hive 'settings' box
├── util/
│   ├── color_util.dart
│   ├── date_time_util.dart
│   ├── dialog_util.dart         # error(), ok(), okCancel(), hint()
│   ├── list_notifier_helper.dart
│   └── list_util.dart           # sortAsc / sortDesc
└── view/
    ├── app_drawer.dart          # class AppDrawer — gradient header, nav tiles, theme toggle
    ├── data_screen.dart         # class DataScreen
    ├── download_screen.dart     # class DownloadScreen
    ├── error_screen.dart        # class ErrorScreen
    ├── home_screen.dart         # class HomeScreen — no AppBar, burger in gradient header
    ├── leitner_screen.dart      # class LeitnerScreen — main study view
    ├── level_screen.dart        # class LevelScreen
    ├── loading_screen.dart      # class LoadingScreen
    ├── merge_screen.dart        # class MergeScreen — edit card form
    ├── persist_screen.dart      # class PersistScreen — add card form
    ├── stats_screen.dart        # class StatsScreen
    ├── sync_screen.dart         # class SyncScreen — startup sync
    └── widget/
        ├── animated_button.dart          # AnimatedButton — isActive, activeColor params
        ├── animated_flag.dart
        ├── animated_gradient_background.dart  # dark/light adaptive gradient
        ├── description_sheet.dart        # DescriptionSheet.show() — modal bottom sheet
        └── icon_button_widget.dart
```

---

## LeitnerScreen — Key Details

**Static constants:** `LeitnerScreen.allLevel = -1`, `LeitnerScreen.allLimitedLevel = -2`
**Burn-in protection (AMOLED):**
- Pixel shifting: `Timer.periodic(30s)` shifts entire view ±2px via `Transform.translate`
- Auto-dim: after 2 minutes idle, `Colors.black` overlay (alpha 0.85) covers screen. Tap to wake.
- Uses `Listener(onPointerDown:)` to catch all touches including children

**Text display:** plain `Text` at 28px, `SingleChildScrollView` for long content, RTL-aware

**Thumb buttons:** `AnimatedButton` with `isActive`/`activeColor`:
- Like → `activeColor: Colors.green` when `levelChanged == LevelDirection.up`
- Dislike → `activeColor: Colors.redAccent` when `levelChanged == LevelDirection.down`

**Description button:** opens `DescriptionSheet.show()` — draggable modal bottom sheet

---

## AnimatedGradientBackground (Card Background)

Adapts to theme brightness:
- **Dark:** `#0D1B2A → #152232 → #1A2B3C → #0F1923` (midnight navy, AMOLED-friendly)
- **Light:** `#E8EDF2 → #D6DFE8 → #CDD8E3 → #D8E3EC` (cool silver-white)

---

## Design System

### Colours
| Context | Colour |
|---|---|
| English accent | `Colors.blue.shade600` |
| Deutsch accent | `Colors.orange.shade700` |
| English gradient | `[Color(0xFF1565C0), Color(0xFF42A5F5)]` |
| Deutsch gradient | `[Color(0xFFE65100), Color(0xFFFFB74D)]` |
| App theme seed | `Color(0xFF3D5A80)` — muted steel blue |

**Level colours — each level has its own unique colour:**
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

### Level icons (emoji in coloured circle)
```
0:🥚  1:🐣  2:🐥  3:🌱  4:🌿  5:🌳  6:⚡  7:🔥
8:💡  9:🎯  10:⭐  11:🌟  12:💫  13:🏆  14:👑  15:💎
```

### Dark mode tokens — always use, never hardcode colours
- Card background → `colorScheme.surface`
- Elevated surface → `colorScheme.surfaceContainerHighest`
- Secondary text → `colorScheme.onSurfaceVariant`
- Borders → `colorScheme.outlineVariant`

### AppBar
```dart
AppBar(backgroundColor: _accentColor, foregroundColor: Colors.white, elevation: 0)
```

### Cards / containers
- `BorderRadius.circular(14)` large, `12` form fields
- `boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]`

### Deprecated API
Always use `.withValues(alpha: x)` — never `.withOpacity(x)` (deprecated in Flutter 3.x)

---

## Key Rules & Gotchas

### Hive IDs
- Max Hive key: `0xFFFFFFFF`. Use seconds epoch `DateTime.now().millisecondsSinceEpoch ~/ 1000`.
- `card_entity.g.dart` references `HiveTypeIds.cardId` by name — re-running `build_runner` will
  overwrite it. Re-apply manually if needed.

### SyncService — all-or-nothing
`saveCard`, `removeCard`, `removeCards` write to both Hive and Supabase with rollback.
Never write directly to Hive or Supabase from views.

### ThemeService must be registered first
`DependencyConfig` registers `ThemeService` before all other services.

### Android package path
`applicationId = "com.flashmind.app"` — the Kotlin folder path must match exactly:
`android/app/src/main/kotlin/com/flashmind/app/MainActivity.kt`
Changing only `build.gradle.kts` is not enough — the folder must also be moved.

### Wireless ADB (Samsung A52)
Two separate steps required:
1. `adb pair <IP:PAIRING_PORT>` — short-lived port shown in "Pair device with pairing code" dialog
2. `adb connect <IP:MAIN_PORT>` — persistent port shown on main "Wireless debugging" screen
These ports are always different. See `docs/android-device-debugging-guide.md` for full steps.

### iOS Simulator SSL
`CERTIFICATE_VERIFY_FAILED` from Supabase — fixed in `main.dart` with `_DevHttpOverrides`
(debug only, `kDebugMode` guard, no effect in release).

### Zscaler (corporate proxy) SSL during `flutter build apk`
Fixed in `android/gradle.properties`:
```properties
org.gradle.jvmargs=... -Djavax.net.ssl.trustStoreType=KeychainStore
```

### HomeScreen — no AppBar
Burger menu lives inside the gradient header. `body` wrapped in `Builder` for `Scaffold.of()`.

### iOS exit button
Removed — iOS HIG discourages quit buttons. Do not add back.

---

## Docs

- `docs/android-device-debugging-guide.md` — wireless ADB + ClassNotFoundException fix
- `docs/known-issues-and-fixes.md` — Gradle SSL, JVM symlink, Android Studio issues

---

## Workflow Conventions

1. **Never commit or push without explicit user instruction.**
2. **Before every commit:** run `dart format lib/` first, then `flutter analyze lib/` — zero errors before committing.
3. Dark mode must work on all screens — use design tokens, never hardcode colours.
4. All new routes go in `route_config.dart` (constant + switch case).
5. All new GetX services go in `dependency_config.dart`.
6. File names: `snake_case.dart`. Class names for screens: `*Screen`. Widgets: descriptive names.
7. **Keep comments up to date with every code change.**
   - Classes: doc comment explaining purpose and key design decisions.
   - Methods: comment if the *why* is not obvious from the name alone.
   - Fields: inline comment when the meaning or constraint isn't self-evident.
   - Do NOT comment obvious one-liners — only where a future reader would ask "why?".
   - When modifying existing code, update or remove stale comments in the same change.

