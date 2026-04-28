import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/permission_service.dart';
import 'package:supermarket/core/auth/auth_provider.dart';

class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isAuthenticated) return fallback ?? const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: sl<PermissionService>().hasPermission(authProvider.currentUser!.id, permission),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == true) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
