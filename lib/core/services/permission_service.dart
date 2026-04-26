import 'package:supermarket/data/datasources/local/app_database.dart';

class PermissionService {
  final AppDatabase db;

  PermissionService(this.db);

  /// Checks if a user has a specific permission
  Future<bool> hasPermission(String userId, String permissionCode) async {
    final user = await (db.select(db.users)..where((u) => u.id.equals(userId))).getSingle();
    
    final permissions = await (db.select(db.rolePermissions)
      ..where((rp) => rp.role.equals(user.role))).get();
      
    return permissions.any((p) => p.permissionCode == permissionCode);
  }
}
