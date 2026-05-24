import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

import '../config/RouteConfig.dart';
import '../service/RouteService.dart';
import '../service/SyncService.dart';

class SyncView extends StatefulWidget {
  const SyncView({super.key});

  @override
  State<SyncView> createState() => _SyncViewState();
}

class _SyncViewState extends State<SyncView> {
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
