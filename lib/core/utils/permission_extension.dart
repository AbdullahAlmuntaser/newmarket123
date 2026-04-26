import 'package:flutter/material.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';

extension PermissionExtension on Widget {
  Widget guard(String permission, {Widget? fallback}) {
    return PermissionGuard(
      permission: permission,
      fallback: fallback,
      child: this,
    );
  }
}
