import 'package:flutter/material.dart';
import 'package:leitner_cards/enums/group_code.dart';

import '../view/data_screen.dart';
import '../view/download_screen.dart';
import '../view/error_screen.dart';
import '../view/home_screen.dart';
import '../view/leitner_screen.dart';
import '../view/level_screen.dart';
import '../view/loading_screen.dart';
import '../view/merge_screen.dart';
import '../view/persist_screen.dart';
import '../view/stats_screen.dart';

/// Named route constants and the [generateRoute] factory for the app.
///
/// All route names are declared as string constants here. [generateRoute]
/// extracts typed arguments from [RouteSettings.arguments] and throws an
/// [ArgumentError] (rendered by [ErrorScreen]) when required params are absent
/// or mistyped, keeping each screen's constructor free of null checks.
class RouteConfig {
  static const String home = "/";
  static const String error = "/error";
  static const String level = "/level";
  static const String data = "/data";
  static const String leitner = "/leitner";
  static const String persist = "/persist";
  static const String merge = "/merge";
  static const String download = "/download";
  static const String stats = "/stats";
  static const String loading = "/loading";

  Route generateRoute(RouteSettings settings) {
    final args = _getArgMap(settings);

    try {
      switch (settings.name) {
        case home:
          return MaterialPageRoute(builder: (_) => const HomeScreen());

        case level:
          return MaterialPageRoute(
              builder: (_) => LevelScreen(
                    groupCode: _getRequired<GroupCode>(args, "groupCode"),
                  ));

        case data:
          return MaterialPageRoute(
              builder: (_) => DataScreen(
                    groupCode: _getRequired<GroupCode>(args, "groupCode"),
                  ));

        case leitner:
          return MaterialPageRoute(
              builder: (_) => LeitnerScreen(
                    groupCode: _getRequired<GroupCode>(args, "groupCode"),
                    level: _getRequired<int>(args, "level"),
                  ));

        case persist:
          return MaterialPageRoute(
              builder: (_) => PersistScreen(
                    groupCode: _getRequired<GroupCode>(args, "groupCode"),
                  ));

        case merge:
          return MaterialPageRoute(
              builder: (_) => MergeScreen(
                    cardEntity: _getRequired(args, "cardEntity"),
                  ));

        case download:
          return MaterialPageRoute(builder: (_) => const DownloadScreen());

        case stats:
          return MaterialPageRoute(builder: (_) => const StatsScreen());

        case loading:
          return MaterialPageRoute(builder: (_) => const LoadingScreen());

        default:
          return MaterialPageRoute(builder: (_) => const ErrorScreen());
      }
    } catch (e) {
      return MaterialPageRoute(
          builder: (_) => ErrorScreen(
                errorMessage: e.toString(),
              ));
    }
  }

  Map<String, dynamic>? _getArgMap(RouteSettings settings) {
    if (settings.arguments == null) return null;
    if (settings.arguments is! Map) {
      throw ArgumentError("Route arguments must be a Map<String, dynamic>.");
    }
    return settings.arguments as Map<String, dynamic>;
  }

  T _getRequired<T>(Map<String, dynamic>? args, String key) {
    if (args == null || !args.containsKey(key) || args[key] == null) {
      throw ArgumentError('Missing required route argument: "$key".');
    }

    final value = args[key];

    if (value is! T) {
      throw ArgumentError(
        'Invalid type for argument "$key". Expected $T, got ${value.runtimeType}.',
      );
    }

    return value;
  }
}
