import 'package:flutter/material.dart';

class AppTheme {
  // Muted indigo-slate — professional, low eye strain, pairs with dark card backgrounds
  static const _seed = Color(0xFF3D5A80);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );
}
