import 'package:flutter/material.dart';
import 'package:supermarket/core/services/role_permissions_service.dart';

/// A widget that conditionally renders its child based on user permissions.
class PermissionGuard extends StatelessWidget {
  /// The permission code required to show the child widget.
  final String permissionCode;
  /// The widget to display if the user has the required permission.
  final Widget child;
  /// The widget to display if the user does not have the required permission.
  /// Defaults to an empty container.
  final Widget? deniedWidget;

  const PermissionGuard({
    super.key,
    required this.permissionCode,
    required this.child,
    this.deniedWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (PermissionsService.hasPermission(permissionCode)) {
      return child;
    } else {
      // Return an empty SizedBox if denied and no deniedWidget is provided.
      // This makes the widget occupy no space.
      return deniedWidget ?? const SizedBox.shrink();
    }
  }
}
