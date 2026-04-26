import 'package:flutter/material.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/role_permissions_service.dart';

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
    final permissionService = sl<PermissionService>();
    if (permissionService.hasPermission(permission)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
