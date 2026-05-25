import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'config/app_theme.dart';
import 'config/dependency_config.dart';
import 'config/route_config.dart';
import 'entity/card_entity.dart';
import 'repository/card_repository.dart';
import 'service/route_service.dart';
import 'service/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS Simulator: override SSL certificate verification in debug builds only
  if (kDebugMode) {
    HttpOverrides.global = _DevHttpOverrides();
  }
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

/// Bypasses SSL certificate verification in debug builds.
/// Required for iOS Simulator where Dart's BoringSSL may fail to verify
/// Supabase's certificate chain. Has no effect in release builds.
class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
