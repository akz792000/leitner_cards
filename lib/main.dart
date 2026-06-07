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
import 'entity/visual_card_entity.dart';
import 'repository/card_repository.dart';
import 'repository/visual_card_repository.dart';
import 'service/route_service.dart';
import 'service/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(const MyApp());
}

Future<void> setup() async {
  tz.initializeTimeZones();

  await Hive.initFlutter();
  Hive.registerAdapter(CardEntityAdapter());
  Hive.registerAdapter(VisualCardEntityAdapter());
  await Hive.openBox<CardEntity>(CardRepository.boxId);
  await Hive.openBox<VisualCardEntity>(VisualCardRepository.boxId);

  final directory = await path_provider.getApplicationDocumentsDirectory();
  debugPrint("Hive directory: ${directory.path}");

  await DependencyConfig.registerDependencies();
}

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
          onGenerateRoute: _routeConfig.generateRoute,
        ));
      },
    );
  }
}
