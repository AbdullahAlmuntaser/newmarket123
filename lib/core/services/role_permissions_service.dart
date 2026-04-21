import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';

class PermissionsService {
  final AppDatabase db;
  List<String> _permissions = [];

  PermissionsService(this.db);

  /// Initializes permissions for the given role.
  Future<void> init(String? role) async {
    if (role == null) {
      _permissions = [];
      return;
    }
    if (role.toLowerCase() == 'admin') {
      _permissions = ['*']; // Super admin has all permissions
      return;
    }

    final results = await (db.select(db.rolePermissions)
          ..where((rp) => rp.role.equals(role)))
        .get();
    _permissions = results.map((rp) => rp.permissionCode).toList();
  }

  /// Checks if the current role has the specified permission.
  bool can(String action) {
    if (_permissions.contains('*')) return true;
    return _permissions.contains(action);
  }

  /// Static shortcut for easy access in UI
  static bool hasPermission(String action) {
    return sl<PermissionsService>().can(action);
  }
}
