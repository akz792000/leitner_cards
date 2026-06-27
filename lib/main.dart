import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sizer/sizer.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'config/app_theme.dart';
import 'config/dependency_config.dart';
import 'config/route_config.dart';
import 'entity/card_entity.dart';
import 'entity/deck_entity.dart';
import 'entity/progress_entity.dart';
import 'repository/card_repository.dart';
import 'repository/deck_repository.dart';
import 'repository/progress_repository.dart';
import 'service/deck_seed_service.dart';
import 'service/route_service.dart';
import 'service/study_log_service.dart';
import 'service/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(const MyApp());
}

/// Initialises Hive, timezone data, and all GetX dependencies before the app starts.
///
/// If the card or progress box cannot be read (e.g. schema mismatch from an
/// older app version), the corrupted box is deleted and reopened empty so the
/// app never crashes on startup. Cards can be re-downloaded via DownloadScreen.
Future<void> setup() async {
  tz.initializeTimeZones();

  await Hive.initFlutter();
  Hive.registerAdapter(CardEntityAdapter());
  Hive.registerAdapter(ProgressEntityAdapter());
  Hive.registerAdapter(DeckEntityAdapter());

  await _openBoxSafe<CardEntity>(CardRepository.boxId);
  await _openBoxSafe<ProgressEntity>(ProgressRepository.boxId);
  await _openBoxSafe<DeckEntity>(DeckRepository.boxId);
  await _openBoxSafe<dynamic>(StudyLogService.boxId);

  final directory = await path_provider.getApplicationDocumentsDirectory();
  debugPrint("Hive directory: ${directory.path}");

  await DependencyConfig.registerDependencies();

  // Seed legacy decks from GroupCode on first launch.
  await DeckSeedService.seedIfNeeded();
}

/// Opens a Hive box, falling back to deleting and recreating it if the stored
/// data cannot be deserialised (e.g. after a schema-breaking migration).
Future<void> _openBoxSafe<T>(String boxId) async {
  try {
    await Hive.openBox<T>(boxId);
  } catch (e) {
    debugPrint('Hive box "$boxId" corrupted ($e) — deleting and recreating.');
    await Hive.deleteBoxFromDisk(boxId);
    await Hive.openBox<T>(boxId);
  }
}

/// Root application widget.
///
/// Wraps [MaterialApp] in an [Obx] so the theme mode reacts to [ThemeService]
/// changes without requiring a full widget rebuild. [Sizer] provides
/// responsive sizing helpers used in some screens.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final RouteConfig _routeConfig = RouteConfig();

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    return Sizer(
      builder: (context, orientation, deviceType) {
        return Obx(() => MaterialApp(
              title: 'FlashMind',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeService.mode,
              debugShowCheckedModeBanner: false,
              navigatorKey: Get.find<RouteService>().navigatorKey,
              navigatorObservers: [
                Get.find<RouteService>().routeObserver,
              ],
              onGenerateRoute: _routeConfig.generateRoute,
            ));
      },
    );
  }
}
