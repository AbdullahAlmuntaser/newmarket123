import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

class DashboardData {
  final double totalSalesToday;
  final double netProfitToday;
  final double inventoryValue;
  final int lowStockCount;
  final int creditLimitExceededCount;

  DashboardData({
    required this.totalSalesToday,
    required this.netProfitToday,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.creditLimitExceededCount,
  });
}

class DashboardProvider with ChangeNotifier {
  final AppDatabase db;
  DashboardData? _data;
  bool _isLoading = false;

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;

  DashboardProvider(this.db) {
    refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    // 1. المبيعات اليومية
    final sales = await (db.select(db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(startOfDay)))
        .get();
    double totalSales = sales.fold(0.0, (sum, s) => sum + s.total);

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

    _data = DashboardData(
      totalSalesToday: totalSales,
      netProfitToday: totalSales * 0.2, // تقدير أولي للربح
      inventoryValue: invValue,
      lowStockCount: lowStock.length,
      creditLimitExceededCount: creditExceeded.length,
    );

    _isLoading = false;
    notifyListeners();
  }
}
