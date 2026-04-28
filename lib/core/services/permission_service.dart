import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

class PermissionService {
  final AppDatabase db;
  
  // Static Permissions Codes
  static const String salesCreate = 'sales_create';
  static const String salesView = 'sales_view';
  static const String salesDelete = 'sales_delete';
  static const String purchasesCreate = 'purchases_create';
  static const String inventoryAdjust = 'inventory_adjust';
  static const String reportsFinancial = 'reports_financial';
  static const String userManagement = 'user_management';
  static const String settingsModify = 'settings_modify';

  PermissionService(this.db);

  /// Checks if a user has a specific permission
  Future<bool> hasPermission(String userId, String permissionCode) async {
    final user = await (db.select(db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (user == null) return false;

    // Admin role always has all permissions
    if (user.role.toLowerCase() == 'admin') return true;
    
    // Check in database for role-based permissions
    final permissions = await (db.select(db.rolePermissions)
      ..where((rp) => rp.role.equals(user.role) & rp.permissionCode.equals(permissionCode)))
      .getSingleOrNull();
      
    return permissions != null;
  }

  /// Initial seed for common roles and permissions
  Future<void> seedPermissions() async {
    final List<String> allPerms = [
      salesCreate, salesView, salesDelete,
      purchasesCreate, inventoryAdjust,
      reportsFinancial, userManagement, settingsModify
    ];

    for (var code in allPerms) {
      await db.into(db.permissions).insertOnConflictUpdate(
        PermissionsCompanion.insert(
          code: code,
          description: Value('Permission for $code'),
        ),
      );
    }

    // Role: Manager
    final managerPerms = [salesView, purchasesCreate, inventoryAdjust, reportsFinancial];
    for (var p in managerPerms) {
      await db.into(db.rolePermissions).insertOnConflictUpdate(
        RolePermissionsCompanion.insert(
          role: 'manager',
          permissionCode: p,
        ),
      );
    }

    // Role: Cashier
    final cashierPerms = [salesCreate, salesView];
    for (var p in cashierPerms) {
      await db.into(db.rolePermissions).insertOnConflictUpdate(
        RolePermissionsCompanion.insert(
          role: 'cashier',
          permissionCode: p,
        ),
      );
    }
  }
}
