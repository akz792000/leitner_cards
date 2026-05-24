import 'package:flutter/material.dart';
import 'package:leitner_cards/enums/GroupCode.dart';

import '../view/DataView.dart';
import '../view/DownloadView.dart';
import '../view/ErrorView.dart';
import '../view/HomeView.dart';
import '../view/LeitnerView.dart';
import '../view/LevelView.dart';
import '../view/LoadingView.dart';
import '../view/MergeView.dart';
import '../view/PersistView.dart';
import '../view/StatsView.dart';
import '../view/SyncView.dart';

class RouteConfig {
  static const String sync = "/";
  static const String home = "/home";
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
        case sync:
          return MaterialPageRoute(builder: (_) => const SyncView());

        case home:
          return MaterialPageRoute(builder: (_) => const HomeView());

        case level:
          return MaterialPageRoute(
              builder: (_) => LevelView(
                groupCode: _getRequired<GroupCode>(args, "groupCode"),
              ));

        case data:
          return MaterialPageRoute(
              builder: (_) => DataView(
                groupCode: _getRequired<GroupCode>(args, "groupCode"),
              ));

        case leitner:
          return MaterialPageRoute(
              builder: (_) => LeitnerView(
                groupCode: _getRequired<GroupCode>(args, "groupCode"),
                level: _getRequired<int>(args, "level"),
              ));

        case persist:
          return MaterialPageRoute(
              builder: (_) => PersistView(
                groupCode: _getRequired<GroupCode>(args, "groupCode"),
              ));

        case merge:
          return MaterialPageRoute(
              builder: (_) => MergeView(
                cardEntity: _getRequired(args, "cardEntity"),
              ));

        case download:
          return MaterialPageRoute(builder: (_) => const DownloadView());

        case stats:
          return MaterialPageRoute(builder: (_) => const StatsView());

        case loading:
          return MaterialPageRoute(builder: (_) => const LoadingView());

        default:
          return MaterialPageRoute(builder: (_) => const ErrorView());
      }
    } catch (e) {
      return MaterialPageRoute(
          builder: (_) => ErrorView(
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
