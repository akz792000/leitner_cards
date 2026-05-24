import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../service/ThemeService.dart';

class DrawerWidget extends StatelessWidget {
  const DrawerWidget({super.key});

  @override
  Widget build(BuildContext context) => Drawer(
    child: SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildMenuItems(context),
        ],
      ),
    ),
  );

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 16;

    return Material(
      color: Colors.blue.shade400,
      child: Container(
        width: double.infinity,
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(top: topPadding, bottom: 16),
        child: const Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage('assets/image.png'),
            ),
            SizedBox(height: 12),
            Text(
              'Ali Karimizandi',
              style: TextStyle(fontSize: 28, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final themeService = Get.find<ThemeService>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Theme toggle
          Obx(() => ListTile(
            leading: Icon(themeService.icon),
            title: const Text('Theme'),
            trailing: Text(
              themeService.label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => themeService.toggle(),
          )),
          const Divider(color: Colors.black26),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About"),
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(color: Colors.black26),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () => SystemNavigator.pop(),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.school_outlined, size: 40, color: Colors.blue),
              ),
              const SizedBox(height: 16),

              // App name & version
              const Text(
                'Learning Leitner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 2.0.0',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'A spaced-repetition flashcard app based on the Leitner system, '
                'helping you learn English and Deutsch vocabulary efficiently.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 20),

              const Divider(),
              const SizedBox(height: 12),

              // Developer info
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundImage: AssetImage('assets/image.png'),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ali Karimizandi',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        'Developer',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
