import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

import '../config/route_config.dart';
import '../service/route_service.dart';
import '../service/sync_service.dart';

/// Startup synchronisation screen shown as the initial route ("/").
///
/// Runs [SyncService.syncOnStartup] while displaying a spinner and a live
/// status message. On completion (success or offline skip) it replaces itself
/// with [HomeScreen] so the back stack starts cleanly at home.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  String _status = 'Starting...';

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    final syncService = Get.find<SyncService>();
    try {
      await syncService.syncOnStartup((status) {
        if (mounted) setState(() => _status = status);
      });
    } catch (e) {
      Get.snackbar(
        'Sync Error',
        e.toString(),
        backgroundColor: Colors.red[700],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) {
        Get.find<RouteService>().pushReplacementNamed(RouteConfig.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SpinKitCubeGrid(color: Colors.white, size: 80.0),
            const SizedBox(height: 32),
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
