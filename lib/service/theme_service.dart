import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

/// Reactive GetX service that persists the user's theme preference to Hive.
///
/// Must be registered first in [DependencyConfig] because [MyApp] reads the
/// theme mode synchronously on its first build. [init] opens the settings box
/// and restores the saved value before the widget tree is rendered.
class ThemeService extends GetxService {
  static const String _boxName = 'settings';
  static const String _themeKey = 'themeMode';

  final _mode = ThemeMode.system.obs;

  ThemeMode get mode => _mode.value;

  static Future<ThemeService> init() async {
    await Hive.openBox(_boxName);
    final stored = Hive.box(_boxName).get(_themeKey, defaultValue: 'system') as String;
    return ThemeService().._mode.value = _fromString(stored);
  }

  void setMode(ThemeMode mode) {
    _mode.value = mode;
    Hive.box(_boxName).put(_themeKey, _toString(mode));
  }

  /// Cycles system → light → dark → system.
  void toggle() {
    switch (_mode.value) {
      case ThemeMode.system:
        setMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        setMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setMode(ThemeMode.system);
        break;
    }
  }

  IconData get icon {
    switch (_mode.value) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String get label {
    switch (_mode.value) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  static ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
