import 'package:flutter/material.dart';

/// Formerly the startup sync screen — no longer used.
///
/// Auto-download on startup was removed. Card decks are now downloaded
/// manually via [DownloadScreen]. This file is kept to avoid git history
/// noise; the class is intentionally empty.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
