import 'package:flutter/material.dart';

/// Material 3 light and dark themes for FlashMind.
///
/// Both themes derive from the same muted steel-blue seed so the palette stays
/// cohesive across brightness modes without extra colour tuning.
class AppTheme {
  // Muted indigo-slate — professional, low eye strain, pairs with dark card backgrounds
  static const _seed = Color(0xFF3D5A80);

  // Slightly taller than the default 56 — more breathing room for two-line titles.
  static const double toolbarHeight = 64;

  static const _appBarTheme = AppBarTheme(
    toolbarHeight: toolbarHeight,
    // 12px right padding so action icons don't sit flush against the screen edge.
    actionsPadding: EdgeInsets.only(right: 12),
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ),
    appBarTheme: _appBarTheme,
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    appBarTheme: _appBarTheme,
  );
}
