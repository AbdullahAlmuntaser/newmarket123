import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Extended permission codes for granular access control
class ExtendedPermissionCode {
  // Sales
  static const String createSale = 'SALE_CREATE';
  static const String editSale = 'SALE_EDIT';
  static const String deleteSale = 'SALE_DELETE';
  static const String approveSale = 'SALE_APPROVE';
  static const String voidSale = 'SALE_VOID';
  static const String discountUpTo5 = 'DISCOUNT_5';
  static const String discountUpTo10 = 'DISCOUNT_10';
  static const String discountUpTo25 = 'DISCOUNT_25';
  static const String discountUnlimited = 'DISCOUNT_UNLIMITED';

  // Purchases
  static const String createPurchase = 'PURCHASE_CREATE';
  static const String approvePurchase = 'PURCHASE_APPROVE';
  static const String editPurchasePrice = 'PURCHASE_EDIT_PRICE';

  // Inventory
  static const String adjustInventory = 'INVENTORY_ADJUST';
  static const String transferStock = 'STOCK_TRANSFER';
  static const String viewCost = 'VIEW_COST';
  static const String writeOff = 'WRITE_OFF';

  // Financial
  static const String viewFinancialReports = 'FINANCIAL_VIEW';
  static const String postJournalEntry = 'JOURNAL_POST';
  static const String closePeriod = 'PERIOD_CLOSE';
  static const String manageAccounts = 'ACCOUNTS_MANAGE';

  // Admin
  static const String manageUsers = 'USERS_MANAGE';
  static const String manageRoles = 'ROLES_MANAGE';
  static const String systemConfig = 'SYSTEM_CONFIG';
  static const String viewAuditLog = 'AUDIT_VIEW';
}

class AdvancedPermissionService {
  final AppDatabase db;

  AdvancedPermissionService(this.db);

  Future<bool> hasPermission(String userId, String permissionCode) async {
    try {
      final user = await (db.select(db.users)
            ..where((u) => u.id.equals(userId)))
          .getSingleOrNull();
      if (user == null) return false;
      if (user.role.toLowerCase() == 'admin') return true;

      final permission = await (db.select(db.rolePermissions)
            ..where((rp) => rp.role.equals(user.role))
            ..where((rp) => rp.permissionCode.equals(permissionCode)))
          .getSingleOrNull();
      return permission != null;
    } catch (e) {
      return false;
    }
  }

  Future<T?> executeIfAllowed<T>(
    String userId,
    String permissionCode,
    Future<T> Function() action,
  ) async {
    if (await hasPermission(userId, permissionCode)) {
      return await action();
    }
    throw Exception('غير مصرح: $permissionCode');
  }

  Future<void> assignPermissionToRole({
    required String role,
    required String permissionCode,
    String? description,
  }) async {
    final existing = await (db.select(db.rolePermissions)
          ..where((rp) => rp.role.equals(role))
          ..where((rp) => rp.permissionCode.equals(permissionCode)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.rolePermissions).insert(
            RolePermissionsCompanion.insert(
              id: Value(const Uuid().v4()),
              role: role,
              permissionCode: permissionCode,
            ),
          );
    }
  }

  Future<void> removePermissionFromRole({
    required String role,
    required String permissionCode,
  }) async {
    await (db.delete(db.rolePermissions)
          ..where((rp) => rp.role.equals(role))
          ..where((rp) => rp.permissionCode.equals(permissionCode)))
        .go();
  }

  Future<List<RolePermission>> getPermissionsForRole(String role) async {
    return (db.select(db.rolePermissions)..where((rp) => rp.role.equals(role)))
        .get();
  }

  Future<bool> canApproveDiscount(
      String userId, Decimal discountPercent) async {
    if (await hasPermission(userId, ExtendedPermissionCode.discountUnlimited)) {
      return true;
    }
    if (discountPercent <= Decimal.parse('5') &&
        await hasPermission(userId, ExtendedPermissionCode.discountUpTo5)) {
      return true;
    }
    if (discountPercent <= Decimal.parse('10') &&
        await hasPermission(userId, ExtendedPermissionCode.discountUpTo10)) {
      return true;
    }
    if (discountPercent <= Decimal.parse('25') &&
        await hasPermission(userId, ExtendedPermissionCode.discountUpTo25)) {
      return true;
    }
    return false;
  }
}
