import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class DashboardStats {
  final double todaySales;
  final double todayPurchases;
  final double currentCash;
  final int lowStockCount;

  DashboardStats({
    required this.todaySales,
    required this.todayPurchases,
    required this.currentCash,
    required this.lowStockCount,
  });
}

class DashboardService {
  final AppDatabase db;

  DashboardService(this.db);

  Future<DashboardStats> getStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    // 1. Today's Sales
    final salesQuery = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(todayStart)));
    final sales = await salesQuery.get();
    double totalSales = sales.fold(0.0, (sum, item) => sum + item.total);

    // 2. Today's Purchases
    final purchasesQuery = db.select(db.purchases)
      ..where((t) => t.date.isBiggerOrEqual(Variable(todayStart)));
    final purchases = await purchasesQuery.get();
    double totalPurchases = purchases.fold(0.0, (sum, item) => sum + item.total);

    // 3. Cash Balance
    final cashAccount = await db.accountingDao.getAccountByCode('1010');
    double cashBalance = 0;
    if (cashAccount != null) {
      cashBalance = await db.accountingDao.getAccountBalance(cashAccount.id);
    }

    // 4. Low Stock
    final lowStock = await (db.select(db.products)
      ..where((t) => t.stock.isSmallerOrEqual(t.alertLimit))).get();



    return DashboardStats(
      todaySales: totalSales,
      todayPurchases: totalPurchases,
      currentCash: cashBalance,
      lowStockCount: lowStock.length,
    );
  }
}
