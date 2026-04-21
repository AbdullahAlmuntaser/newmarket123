import 'package:flutter/material.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';

extension PermissionExtension on Widget {
  Widget guard(String permissionCode, {Widget? deniedWidget}) {
    return PermissionGuard(
      permissionCode: permissionCode,
      deniedWidget: deniedWidget,
      child: this,
    );
  }
}
