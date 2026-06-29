import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

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
  static const String editTax = 'EDIT_TAX';
  static const String createSalesOrder = 'CREATE_SALES_ORDER';
  static const String editSalesOrder = 'EDIT_SALES_ORDER';
  static const String deleteSalesOrder = 'DELETE_SALES_ORDER';
  static const String approveSalesOrder = 'APPROVE_SALES_ORDER';
  static const String printBarcode = 'PRINT_BARCODE';
  static const String exportData = 'EXPORT_DATA';
  static const String viewCustomerReport = 'VIEW_CUSTOMER_REPORT';
  static const String viewSupplierReport = 'VIEW_SUPPLIER_REPORT';
  static const String viewPurchaseReport = 'VIEW_PURCHASE_REPORT';
  static const String viewCashboxReport = 'VIEW_CASHBOX_REPORT';
  static const String viewInventoryReport = 'VIEW_INVENTORY_REPORT';
  static const String viewProfitReport = 'VIEW_PROFIT_REPORT';

  // Per-screen permissions
  static const String viewProducts = 'VIEW_PRODUCTS';
  static const String createProduct = 'CREATE_PRODUCT';
  static const String editProduct = 'EDIT_PRODUCT';
  static const String deleteProduct = 'DELETE_PRODUCT';
  static const String viewCustomers = 'VIEW_CUSTOMERS';
  static const String createCustomer = 'CREATE_CUSTOMER';
  static const String editCustomer = 'EDIT_CUSTOMER';
  static const String deleteCustomer = 'DELETE_CUSTOMER';
  static const String viewSuppliers = 'VIEW_SUPPLIERS';
  static const String createSupplier = 'CREATE_SUPPLIER';
  static const String editSupplier = 'EDIT_SUPPLIER';
  static const String deleteSupplier = 'DELETE_SUPPLIER';
  static const String viewSales = 'VIEW_SALES';
  static const String createSale = 'CREATE_SALE';
  static const String editSale = 'EDIT_SALE';
  static const String viewPurchases = 'VIEW_PURCHASES';
  static const String createPurchase = 'CREATE_PURCHASE';
  static const String editPurchase = 'EDIT_PURCHASE';
  static const String viewManufacturing = 'VIEW_MANUFACTURING';
  static const String createManufacturing = 'CREATE_MANUFACTURING';
  static const String viewHR = 'VIEW_HR';
  static const String manageHR = 'MANAGE_HR';
  static const String viewAccounting = 'VIEW_ACCOUNTING';
  static const String manageAccounting = 'MANAGE_ACCOUNTING';

  // Per-report permissions
  static const String viewSalesReport = 'VIEW_SALES_REPORT';
  static const String viewAdvancedProfitReport = 'VIEW_ADVANCED_PROFIT_REPORT';
  static const String viewTopSellingReport = 'VIEW_TOP_SELLING_REPORT';
  static const String viewSlowMovingReport = 'VIEW_SLOW_MOVING_REPORT';
  static const String viewStockMovementReport = 'VIEW_STOCK_MOVEMENT_REPORT';
  static const String viewItemMovementReport = 'VIEW_ITEM_MOVEMENT_REPORT';
  static const String viewVATReport = 'VIEW_VAT_REPORT';
  static const String viewAgingReport = 'VIEW_AGING_REPORT';
  static const String viewCashFlowReport = 'VIEW_CASH_FLOW_REPORT';
  static const String viewAuditReport = 'VIEW_AUDIT_REPORT';
  static const String viewExpensesReport = 'VIEW_EXPENSES_REPORT';
  static const String viewIncomeExpenseReport = 'VIEW_INCOME_EXPENSE_REPORT';

  // Financial operation permissions
  static const String createJournalEntry = 'CREATE_JOURNAL_ENTRY';
  static const String approveJournalEntry = 'APPROVE_JOURNAL_ENTRY';
  static const String manageCashbox = 'MANAGE_CASHBOX';
  static const String manageTransfers = 'MANAGE_TRANSFERS';
  static const String manageChecks = 'MANAGE_CHECKS';
  static const String manageFixedAssets = 'MANAGE_FIXED_ASSETS';
  static const String manageBudgets = 'MANAGE_BUDGETS';
  static const String closePeriod = 'CLOSE_PERIOD';
  static const String manageReconciliation = 'MANAGE_RECONCILIATION';
}

class PermissionService {
  final AppDatabase db;

  PermissionService(this.db);

  static const Map<String, String> allPermissions = {
    PermissionCode.postSale: 'تسجيل المبيعات',
    PermissionCode.postPurchase: 'تسجيل المشتريات',
    PermissionCode.postSaleReturn: 'تسجيل مردودات المبيعات',
    PermissionCode.postPurchaseReturn: 'تسجيل مردودات المشتريات',
    PermissionCode.deleteInvoice: 'حذف الفواتير',
    PermissionCode.voidTransaction: 'إلغاء الحركات',
    PermissionCode.manageUsers: 'إدارة المستخدمين',
    PermissionCode.viewReports: 'عرض التقارير',
    PermissionCode.manageSettings: 'إدارة الإعدادات',
    PermissionCode.manageInventory: 'إدارة المخزون',
    PermissionCode.approveDiscount: 'الموافقة على الخصومات',
    PermissionCode.editTax: 'تعديل الضريبة',
    PermissionCode.createSalesOrder: 'إنشاء طلبيات مبيعات',
    PermissionCode.editSalesOrder: 'تعديل طلبيات المبيعات',
    PermissionCode.deleteSalesOrder: 'حذف طلبيات المبيعات',
    PermissionCode.approveSalesOrder: 'الموافقة على طلبيات المبيعات',
    PermissionCode.printBarcode: 'طباعة الباركود',
    PermissionCode.exportData: 'تصدير البيانات',
    PermissionCode.viewCustomerReport: 'تقرير العملاء',
    PermissionCode.viewSupplierReport: 'تقرير الموردين',
    PermissionCode.viewPurchaseReport: 'تقرير المشتريات',
    PermissionCode.viewCashboxReport: 'تقرير الصناديق',
    PermissionCode.viewInventoryReport: 'تقرير المخزون',
    PermissionCode.viewProfitReport: 'تقرير الأرباح',
    PermissionCode.viewProducts: 'عرض المنتجات',
    PermissionCode.createProduct: 'إضافة منتج',
    PermissionCode.editProduct: 'تعديل منتج',
    PermissionCode.deleteProduct: 'حذف منتج',
    PermissionCode.viewCustomers: 'عرض العملاء',
    PermissionCode.createCustomer: 'إضافة عميل',
    PermissionCode.editCustomer: 'تعديل عميل',
    PermissionCode.deleteCustomer: 'حذف عميل',
    PermissionCode.viewSuppliers: 'عرض الموردين',
    PermissionCode.createSupplier: 'إضافة مورد',
    PermissionCode.editSupplier: 'تعديل مورد',
    PermissionCode.deleteSupplier: 'حذف مورد',
    PermissionCode.viewSales: 'عرض المبيعات',
    PermissionCode.createSale: 'إنشاء فاتورة مبيعات',
    PermissionCode.editSale: 'تعديل فاتورة مبيعات',
    PermissionCode.viewPurchases: 'عرض المشتريات',
    PermissionCode.createPurchase: 'إنشاء فاتورة مشتريات',
    PermissionCode.editPurchase: 'تعديل فاتورة مشتريات',
    PermissionCode.viewManufacturing: 'عرض التصنيع',
    PermissionCode.createManufacturing: 'إنشاء أمر تصنيع',
    PermissionCode.viewHR: 'عرض الموارد البشرية',
    PermissionCode.manageHR: 'إدارة الموارد البشرية',
    PermissionCode.viewAccounting: 'عرض المحاسبة',
    PermissionCode.manageAccounting: 'إدارة المحاسبة',
    PermissionCode.viewSalesReport: 'تقرير المبيعات',
    PermissionCode.viewAdvancedProfitReport: 'تقرير الأرباح المتقدم',
    PermissionCode.viewTopSellingReport: 'تقرير الأكثر مبيعاً',
    PermissionCode.viewSlowMovingReport: 'تقرير المنتجات الراكدة',
    PermissionCode.viewStockMovementReport: 'تقرير حركة المخزون',
    PermissionCode.viewItemMovementReport: 'تقرير حركة الصنف',
    PermissionCode.viewVATReport: 'تقرير ضريبة القيمة المضافة',
    PermissionCode.viewAgingReport: 'تقرير أعمار الديون',
    PermissionCode.viewCashFlowReport: 'تقرير التدفق النقدي',
    PermissionCode.viewAuditReport: 'تقرير سجل التدقيق',
    PermissionCode.viewExpensesReport: 'تقرير المصروفات',
    PermissionCode.viewIncomeExpenseReport: 'تقرير الإيرادات والمصروفات',
    PermissionCode.createJournalEntry: 'إنشاء قيد يومية',
    PermissionCode.approveJournalEntry: 'الموافقة على قيد يومية',
    PermissionCode.manageCashbox: 'إدارة الصناديق',
    PermissionCode.manageTransfers: 'إدارة التحويلات',
    PermissionCode.manageChecks: 'إدارة الشيكات',
    PermissionCode.manageFixedAssets: 'إدارة الأصول الثابتة',
    PermissionCode.manageBudgets: 'إدارة الميزانيات',
    PermissionCode.closePeriod: 'إغلاق الفترة المحاسبية',
    PermissionCode.manageReconciliation: 'إدارة التسوية البنكية',
  };

  Future<void> seedPermissions() async {
    for (final entry in allPermissions.entries) {
      await db.into(db.permissions).insert(
            PermissionsCompanion.insert(
              code: entry.key,
              description: Value(entry.value),
            ),
            onConflict: DoUpdate(
              (_) => PermissionsCompanion(
                description: Value(entry.value),
              ),
              target: [db.permissions.code],
            ),
          );
    }
  }

  /// التحقق من أن المستخدم لديه الصلاحية المطلوبة
  Future<bool> hasPermission(String userId, String permissionCode) async {
    try {
      final user = db.select(db.users)..where((u) => u.id.equals(userId));
      final userData = await user.getSingleOrNull();
      if (userData == null) return false;

      if (userData.role.toLowerCase() == 'admin') return true;

      final permission = await (db.select(db.rolePermissions)
            ..where((rp) => rp.role.equals(userData.role))
            ..where((rp) => rp.permissionCode.equals(permissionCode)))
          .getSingleOrNull();
      return permission != null;
    } catch (e) {
      return false;
    }
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
