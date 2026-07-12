import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/audit_service.dart';

class DashboardData {
  final double totalSalesToday;
  final double netProfitToday;
  final double inventoryValue;
  final int lowStockCount;
  final int creditLimitExceededCount;
  final int totalCustomers;
  final int totalSuppliers;
  final double totalPurchasesToday;
  final double cashboxBalance;
  final int pendingOrdersCount;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> categoryBreakdown;

  DashboardData({
    required this.totalSalesToday,
    required this.netProfitToday,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.creditLimitExceededCount,
    this.totalCustomers = 0,
    this.totalSuppliers = 0,
    this.totalPurchasesToday = 0,
    this.cashboxBalance = 0,
    this.pendingOrdersCount = 0,
    this.topProducts = const [],
    this.categoryBreakdown = const [],
  });
}

class DashboardProvider with ChangeNotifier {
  final AppDatabase db;
  DashboardData? _data;
  bool _isLoading = false;
  String? _error;

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DashboardProvider(this.db) {
    refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // 1. المبيعات اليومية
      final sales = await (db.select(db.sales)
            ..where((s) => s.createdAt.isBiggerOrEqual(Variable(startOfDay))))
          .get();
      double totalSales = sales
          .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.total)
          .toDouble();

      // 2. القيمة الإجمالية للمخزون
      double invValue = await db.calculateTotalInventoryValue();

      // 3. المنتجات منخفضة المخزون
      final lowStock = await (db.select(db.products)
            ..where((p) => p.stock.isSmallerOrEqual(p.alertLimit)))
          .get();

      // 4. العملاء المتجاوزين للائتمان
      final creditExceeded = await (db.select(db.customers)
            ..where((c) => c.balance.isBiggerThan(c.creditLimit)))
          .get();

      // 5. حساب الأرباح الفعلية من COGS
      double totalCOGS = 0;
      final todaySaleIds = sales.map((s) => s.id).toList();
      if (todaySaleIds.isNotEmpty) {
        final saleItems = await (db.select(db.saleItems)
              ..where((si) => si.saleId.isIn(todaySaleIds)))
            .get();
        for (final item in saleItems) {
          final product = await (db.select(db.products)
                ..where((p) => p.id.equals(item.productId)))
              .getSingleOrNull();
          if (product != null) {
            totalCOGS += (product.buyPrice * item.quantity).toDouble();
          }
        }
      }

      // 6. عدد العملاء الكلي
      final allCustomers = await (db.select(db.customers)..limit(1000)).get();

      // 7. عدد الموردين الكلي
      final allSuppliers = await (db.select(db.suppliers)..limit(1000)).get();

      // 8. المشتريات اليومية
      final purchases = await (db.select(db.purchases)
            ..where((p) => p.createdAt.isBiggerOrEqual(Variable(startOfDay))))
          .get();
      double totalPurchases = purchases
          .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.total)
          .toDouble();

      // 9. رصيد الصندوق
      double cashboxBalance = 0;
      try {
        final cashTransactions =
            await (db.select(db.cashboxTransactions)..limit(500)).get();
        cashboxBalance = cashTransactions
            .fold<Decimal>(Decimal.zero, (sum, t) => sum + t.amount)
            .toDouble();
      } catch (_) {}

      // 10. الطلبيات المعلقة
      int pendingOrders = 0;
      try {
        final pendingOrdersList = await (db.select(db.salesOrders)
              ..where((o) => o.status.equals('PENDING')))
            .get();
        pendingOrders = pendingOrdersList.length;
      } catch (_) {}

      // 11. أفضل المنتجات مبيعاً
      List<Map<String, dynamic>> topProducts = [];
      try {
        if (todaySaleIds.isNotEmpty) {
          final saleItemsForTop = await (db.select(db.saleItems)
                ..where((si) => si.saleId.isIn(todaySaleIds)))
              .get();
          final productQtyMap = <String, double>{};
          for (final item in saleItemsForTop) {
            productQtyMap[item.productId] =
                (productQtyMap[item.productId] ?? 0) + item.quantity.toDouble();
          }
          final sortedEntries = productQtyMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          for (final entry in sortedEntries.take(5)) {
            final product = await (db.select(db.products)
                  ..where((p) => p.id.equals(entry.key)))
                .getSingleOrNull();
            if (product != null) {
              topProducts.add({
                'name': product.name,
                'quantity': entry.value,
                'revenue': product.sellPrice.toDouble() * entry.value,
              });
            }
          }
        }
      } catch (_) {}

      // 12. تصنيف المنتجات
      List<Map<String, dynamic>> categoryBreakdown = [];
      try {
        final categories = await (db.select(db.categories)).get();
        for (final cat in categories.take(6)) {
          final catProducts = await (db.select(db.products)
                ..where((p) => p.categoryId.equals(cat.id)))
              .get();
          final catValue = catProducts.fold<Decimal>(
              Decimal.zero, (sum, p) => sum + (p.sellPrice * p.stock));
          categoryBreakdown.add({
            'name': cat.name,
            'count': catProducts.length,
            'value': catValue.toDouble(),
          });
        }
      } catch (_) {}

      _data = DashboardData(
        totalSalesToday: totalSales,
        netProfitToday: totalSales - totalCOGS,
        inventoryValue: invValue,
        lowStockCount: lowStock.length,
        creditLimitExceededCount: creditExceeded.length,
        totalCustomers: allCustomers.length,
        totalSuppliers: allSuppliers.length,
        totalPurchasesToday: totalPurchases,
        cashboxBalance: cashboxBalance,
        pendingOrdersCount: pendingOrders,
        topProducts: topProducts,
        categoryBreakdown: categoryBreakdown,
      );
    } catch (e) {
      _error = e.toString();
      await sl<AuditService>().logAction(
        userId: 'system',
        action: 'DASHBOARD_REFRESH_ERROR',
        logTableName: 'Dashboard',
        recordId: 'all',
        newValues: {'error': e.toString()},
      );
    }

    _isLoading = false;
    notifyListeners();
  }
}
