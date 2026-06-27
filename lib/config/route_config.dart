import 'package:flutter/material.dart';
import 'package:leitner_cards/enums/group_code.dart';

import '../entity/deck_entity.dart';
import '../view/create_deck_screen.dart';
import '../view/data_screen.dart';
import '../view/deck_detail_screen.dart';
import '../view/download_screen.dart';
import '../view/edit_deck_screen.dart';
import '../view/error_screen.dart';
import '../view/home_screen.dart';
import '../view/leitner_screen.dart';
import '../view/level_screen.dart';
import '../view/merge_screen.dart';
import '../view/persist_screen.dart';
import '../view/settings_screen.dart';
import '../view/stats_screen.dart';

/// Named route constants and the [generateRoute] factory for the app.
///
/// All route names are declared as string constants here. [generateRoute]
/// extracts typed arguments from [RouteSettings.arguments] and throws an
/// [ArgumentError] (rendered by [ErrorScreen]) when required params are absent
/// or mistyped, keeping each screen's constructor free of null checks.
///
/// The app is offline-first — `/` loads [HomeScreen] directly.
/// Authentication is on-demand (triggered from the Sync screen).
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
  static const String settings = "/settings";
  static const String createDeck = "/create-deck";
  static const String deckDetail = "/deck-detail";
  static const String editDeck = "/edit-deck";

  Route generateRoute(RouteSettings routeSettings) {
    final args = _getArgMap(routeSettings);

    try {
      switch (routeSettings.name) {
        case home:
          return MaterialPageRoute(builder: (_) => const HomeScreen());

        case level:
          return MaterialPageRoute(
              builder: (_) => LevelScreen(
                    groupCode: args?['groupCode'] as GroupCode?,
                    deckId: args?['deckId'] as String?,
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
                    groupCode: args?['groupCode'] as GroupCode?,
                    deck: args?['deck'] as DeckEntity?,
                  ));

        case merge:
          return MaterialPageRoute(
              builder: (_) => MergeScreen(
                    cardEntity: _getRequired(args, "cardEntity"),
                    deck: args?['deck'] as DeckEntity?,
                  ));

        case download:
          return MaterialPageRoute(builder: (_) => const DownloadScreen());

        case stats:
          return MaterialPageRoute(builder: (_) => const StatsScreen());

        case settings:
          return MaterialPageRoute(builder: (_) => const SettingsScreen());

        case createDeck:
          return MaterialPageRoute(builder: (_) => const CreateDeckScreen());

        case deckDetail:
          return MaterialPageRoute(
              builder: (_) => DeckDetailScreen(
                    deckId: _getRequired<String>(args, "deckId"),
                  ));

        case editDeck:
          return MaterialPageRoute(
              builder: (_) => EditDeckScreen(
                    deckId: _getRequired<String>(args, "deckId"),
                  ));

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

  Map<String, dynamic>? _getArgMap(RouteSettings routeSettings) {
    if (routeSettings.arguments == null) return null;
    if (routeSettings.arguments is! Map) {
      throw ArgumentError("Route arguments must be a Map<String, dynamic>.");
    }
    return routeSettings.arguments as Map<String, dynamic>;
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
