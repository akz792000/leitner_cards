import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'config/AppTheme.dart';
import 'config/DependencyConfig.dart';
import 'config/RouteConfig.dart';
import 'entity/CardEntity.dart';
import 'repository/CardRepository.dart';
import 'service/RouteService.dart';
import 'service/ThemeService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(const MyApp());
}

Future<void> setup() async {
  // Time zones
  tz.initializeTimeZones();

  // Environment
  await dotenv.load(fileName: '.env');

  // Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Hive
  await Hive.initFlutter();

  Hive.registerAdapter(CardEntityAdapter());

  await Hive.openBox<CardEntity>(CardRepository.boxId);

  Directory directory = await path_provider.getApplicationDocumentsDirectory();
  debugPrint("Hive directory: ${directory.path}");

  // Dependency injection
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
          title: 'Learning Leitner',
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
