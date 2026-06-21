import 'package:flutter/material.dart';

/// Shared colour helpers used across multiple screens.
class ColorUtil {
  ColorUtil._();

  /// Returns the level badge colour for [level], adapted to [brightness].
  ///
  /// Light colours (amber, yellow, lime) are replaced with darker shades in
  /// light theme so they remain legible against a white background.
  static Color levelColor(int level, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    const darkColors = [
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

    // Light-theme variants: high-luminance colours darkened to stay readable.
    const lightColors = [
      Color(0xFFC62828), // 0  red 800
      Color(0xFFBF360C), // 1  deep orange 900
      Color(0xFFE65100), // 2  orange 900
      Color(0xFFFF8F00), // 3  amber 800
      Color(0xFFF9A825), // 4  amber 700 (replaces near-white yellow)
      Color(0xFF558B2F), // 5  light green 800 (replaces light lime)
      Color(0xFF2E7D32), // 6  green 800
      Color(0xFF1B5E20), // 7  green 900
      Color(0xFF00695C), // 8  teal 800
      Color(0xFF00838F), // 9  cyan 800
      Color(0xFF0277BD), // 10 light blue 800
      Color(0xFF1565C0), // 11 blue 800
      Color(0xFF283593), // 12 indigo 800
      Color(0xFF4527A0), // 13 deep purple 800
      Color(0xFF6A1B9A), // 14 purple 800
      Color(0xFFAD1457), // 15 pink 800
    ];

    final colors = isDark ? darkColors : lightColors;
    return colors[level.clamp(0, colors.length - 1)];
  }
}
