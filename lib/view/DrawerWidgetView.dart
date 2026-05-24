import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final bottomPadding = 16.0;

    return Material(
      color: Colors.blue.shade400,
      child: InkWell(
        onTap: () {},
        child: Container(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage('assets/image.png'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ali Karimizandi',
                style: TextStyle(fontSize: 28, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text("About"),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationIcon: const FlutterLogo(),
              applicationName: "Learning Leitner",
              applicationVersion: '2.0.0',
              applicationLegalese: 'Developed by Ali Karimizandi',
            );
          },
        ),
        const Divider(color: Colors.black54),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text("Logout"),
          onTap: () {
            debugPrint("Logout pressed.");
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else if (Platform.isIOS) {
              exit(0);
            }
          },
        ),
      ],
    ),
  );
}
