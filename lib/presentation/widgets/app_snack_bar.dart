import 'package:flutter/material.dart';

enum AppSnackBarType { success, error, warning, info }

class AppSnackBar {
  const AppSnackBar._();

  static void success(BuildContext context, String message) => _show(
        context,
        message,
        type: AppSnackBarType.success,
      );

  static void error(BuildContext context, String message) => _show(
        context,
        message,
        type: AppSnackBarType.error,
        duration: const Duration(seconds: 5),
      );

  static void warning(BuildContext context, String message) => _show(
        context,
        message,
        type: AppSnackBarType.warning,
      );

  static void info(BuildContext context, String message) => _show(
        context,
        message,
        type: AppSnackBarType.info,
      );

  static void _show(
    BuildContext context,
    String message, {
    required AppSnackBarType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: _backgroundColor(type),
      ),
    );
  }

  static Color _backgroundColor(AppSnackBarType type) {
    switch (type) {
      case AppSnackBarType.success:
        return Colors.green.shade700;
      case AppSnackBarType.error:
        return Colors.red.shade700;
      case AppSnackBarType.warning:
        return Colors.orange.shade800;
      case AppSnackBarType.info:
        return Colors.blueGrey.shade700;
    }
  }
}
