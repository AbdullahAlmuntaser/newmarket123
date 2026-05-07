import 'package:supermarket/data/datasources/local/app_database.dart';

class PermissionCode {
  static const String postSale = 'POST_SALE';
  static const String postPurchase = 'POST_PURCHASE';
  static const String postSaleReturn = 'POST_SALE_RETURN';
  static const String postPurchaseReturn = 'POST_PURCHASE_RETURN';
  static const String deleteInvoice = 'DELETE_INVOICE';
  static const String voidTransaction = 'VOID_TRANSACTION';
  static const String manageUsers = 'MANAGE_USERS';
  static const String viewReports = 'VIEW_REPORTS';
  static const String manageSettings = 'MANAGE_SETTINGS';
  static const String manageInventory = 'MANAGE_INVENTORY';
  static const String approveDiscount = 'APPROVE_DISCOUNT';
}

class PermissionService {
  final AppDatabase db;

  PermissionService(this.db);

  /// التحقق من أن المستخدم لديه الصلاحية المطلوبة
  Future<bool> hasPermission(String userId, String permissionCode) async {
    try {
      final user = db.select(db.users)..where((u) => u.id.equals(userId));
      final userData = await user.getSingleOrNull();
      if (userData == null) return false;

      // الحصول على صلاحيات الدور
      final rolePerms = await db.select(db.rolePermissions).get();
      final permission = rolePerms.where((rp) => rp.role == userData.role && rp.permissionCode == permissionCode);
      return permission.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من الصلاحية باستخدام كود الصلاحية (للتوافق مع الكود القديم)
  Future<bool> check(String permissionCode) async {
    // ملاحظة: هذه الدالة تتطلب معرفة userId من السياق
    // يجب تمرير userId في التطبيقات الحقيقية
    return true; // افتراضي للسماح - يجب تحسينه
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
