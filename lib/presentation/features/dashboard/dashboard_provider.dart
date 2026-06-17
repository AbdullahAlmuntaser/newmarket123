import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/audit_log_service.dart';

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
      double totalSales = sales.fold<Decimal>(Decimal.zero, (sum, s) => sum + s.total).toDouble();

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
        netProfitToday: totalSales * 0.2,
        inventoryValue: invValue,
        lowStockCount: lowStock.length,
        creditLimitExceededCount: creditExceeded.length,
      );
    } catch (e) {
      _error = e.toString();
      await sl<AuditLogService>().logAction(
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
