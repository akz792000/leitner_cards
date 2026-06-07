import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Generic full-screen loading indicator used during navigation transitions.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: const Center(
        child: SpinKitCubeGrid(
          color: Colors.white,
          size: 80.0,
        ),
      ),
    );
  }
}
