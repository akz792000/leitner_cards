import 'package:flutter/material.dart';

class DialogUtil {

  static void error(BuildContext context, dynamic exception) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(exception.toString()),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static Future<void> okCancel(
      BuildContext context, {
        required String title,
        required String description,
        VoidCallback? onOk,
      }) async {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> ok(
      BuildContext context, {
        required String title,
        required String description,
        VoidCallback? onOk,
      }) async {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> hint(
      BuildContext context, {
        required String description,
        double horizontalPadding = 100,
      }) async {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        content: Text(description),
      ),
    );
  }
}
