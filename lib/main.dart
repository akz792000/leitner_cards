import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sizer/sizer.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'config/DependencyConfig.dart';
import 'config/RouteConfig.dart';
import 'entity/CardEntity.dart';
import 'entity/InfoEntity.dart';
import 'repository/CardRepository.dart';
import 'repository/InfoRepository.dart';
import 'service/RouteService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(const MyApp());
}

Future<void> setup() async {
  // Time zones
  tz.initializeTimeZones();

  // Hive
  await Hive.initFlutter();

  Hive.registerAdapter(CardEntityAdapter());
  Hive.registerAdapter(InfoEntityAdapter());

  await Hive.openBox<CardEntity>(CardRepository.boxId);
  await Hive.openBox<InfoEntity>(InfoRepository.boxId);

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
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'zleitner',
          theme: ThemeData(
            primarySwatch: Colors.lightBlue,
            useMaterial3: true, // modern UI
          ),
          debugShowCheckedModeBanner: false,
          navigatorKey: Get.find<RouteService>().navigatorKey,
          onGenerateRoute: _routeConfig.generateRoute,
        );
      },
    );
  }
}
