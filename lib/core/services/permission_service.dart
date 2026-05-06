import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

class PermissionService {
  final AppDatabase db;

  PermissionService(this.db);

  /// التحقق من أن المستخدم لديه الصلاحية المطلوبة
  Future<bool> hasPermission(String userId, String permissionCode) async {
    final user = db.select(db.users)..where((u) => u.id.equals(userId));
    final userData = await user.getSingleOrNull();
    if (userData == null) return false;

    // الحصول على صلاحيات الدور
    final query = db.select(db.rolePermissions)
        ..where((rp) => rp.role.equals(userData.role) & rp.permissionCode.equals(permissionCode));
    
    final permission = await query.getSingleOrNull();
    return permission != null;
  }

  /// تنفيذ عملية فقط إذا كان المستخدم يملك الصلاحية
  Future<T?> executeIfAllowed<T>(
    String userId,
    String permissionCode,
    Future<T> Function() action,
  ) async {
    if (await hasPermission(userId, permissionCode)) {
      return await action();
    } else {
      throw Exception('غير مصرح لك بتنفيذ هذه العملية ($permissionCode)');
    }
  }
}
