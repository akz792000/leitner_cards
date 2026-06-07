import 'package:flutter/material.dart';

/// Fallback screen shown when route generation fails or an unknown route is requested.
///
/// [errorMessage] is populated by [RouteConfig.generateRoute] when required
/// route arguments are missing or have the wrong type.
class ErrorScreen extends StatelessWidget {
  final String? errorMessage;

  const ErrorScreen({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final displayMessage = errorMessage ?? "An unexpected error occurred.";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Error"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.redAccent.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text("Go Back"),
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
