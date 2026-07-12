import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class DashboardStats {
  final double todaySales;
  final double todayPurchases;
  final double currentCash;
  final int lowStockCount;
  final double weeklySales;
  final double monthlySales;
  final int todayTransactions;
  final int pendingOrders;
  final double todayProfit;

  DashboardStats({
    required this.todaySales,
    required this.todayPurchases,
    required this.currentCash,
    required this.lowStockCount,
    this.weeklySales = 0,
    this.monthlySales = 0,
    this.todayTransactions = 0,
    this.pendingOrders = 0,
    this.todayProfit = 0,
  });
}

class SalesDataPoint {
  final DateTime date;
  final double amount;
  final int count;

  SalesDataPoint({
    required this.date,
    required this.amount,
    required this.count,
  });
}

class TopProduct {
  final String id;
  final String name;
  final double revenue;
  final int quantity;

  TopProduct({
    required this.id,
    required this.name,
    required this.revenue,
    required this.quantity,
  });
}

class CategorySales {
  final String categoryName;
  final double amount;
  final double percentage;

  CategorySales({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });
}

class DashboardService {
  final AppDatabase db;

  DashboardService(this.db);

  Future<DashboardStats> getStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart =
        todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final salesQuery = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(todayStart)));
    final todaySalesList = await salesQuery.get();
    double todaySales = todaySalesList
        .fold<Decimal>(Decimal.zero, (sum, item) => sum + item.total)
        .toDouble();
    int todayTransactions = todaySalesList.length;

    final weekSalesQuery = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(weekStart)));
    final weekSalesList = await weekSalesQuery.get();
    double weeklySales = weekSalesList
        .fold<Decimal>(Decimal.zero, (sum, item) => sum + item.total)
        .toDouble();

    final monthSalesQuery = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(monthStart)));
    final monthSalesList = await monthSalesQuery.get();
    double monthlySales = monthSalesList
        .fold<Decimal>(Decimal.zero, (sum, item) => sum + item.total)
        .toDouble();

    final purchasesQuery = db.select(db.purchases)
      ..where((t) => t.date.isBiggerOrEqual(Variable(todayStart)));
    final purchases = await purchasesQuery.get();
    double totalPurchases = purchases
        .fold<Decimal>(Decimal.zero, (sum, item) => sum + item.total)
        .toDouble();

    final cashAccount = await db.accountingDao.getAccountByCode('1010');
    double cashBalance = 0;
    if (cashAccount != null) {
      cashBalance =
          (await db.accountingDao.getAccountBalance(cashAccount.id)).toDouble();
    }

    final lowStock = await (db.select(db.products)
          ..where((t) => t.stock.isSmallerOrEqual(t.alertLimit)))
        .get();

    final pendingOrdersQuery = db.select(db.purchaseOrders)
      ..where((t) => t.status.equals('pending'));
    final pendingOrders = await pendingOrdersQuery.get();

    double todayProfit = todaySales - totalPurchases;

    return DashboardStats(
      todaySales: todaySales,
      todayPurchases: totalPurchases,
      currentCash: cashBalance,
      lowStockCount: lowStock.length,
      weeklySales: weeklySales,
      monthlySales: monthlySales,
      todayTransactions: todayTransactions,
      pendingOrders: pendingOrders.length,
      todayProfit: todayProfit,
    );
  }

  Future<List<SalesDataPoint>> getWeeklySalesData() async {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 6));
    final result = <SalesDataPoint>[];

    for (int i = 0; i < 7; i++) {
      final dayStart = weekStart.add(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));

      final daySales =
          await db.salesDao.getInvoicesByDateRange(dayStart, dayEnd);

      result.add(SalesDataPoint(
        date: dayStart,
        amount: daySales
            .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.total)
            .toDouble(),
        count: daySales.length,
      ));
    }

    return result;
  }

  Future<List<SalesDataPoint>> getMonthlySalesData() async {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final result = <SalesDataPoint>[];

    for (int i = 1; i <= daysInMonth; i += 5) {
      final dayStart = DateTime(now.year, now.month, i);
      final dayEnd = dayStart.add(const Duration(days: 5));

      final daySales =
          await db.salesDao.getInvoicesByDateRange(dayStart, dayEnd);

      result.add(SalesDataPoint(
        date: dayStart,
        amount: daySales
            .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.total)
            .toDouble(),
        count: daySales.length,
      ));
    }

    return result;
  }

  Future<List<TopProduct>> getTopProducts({int limit = 5}) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final quantitySum =
        CustomExpression<double>('SUM(${db.saleItems.quantity.name})');
    final revenueSum = CustomExpression<double>(
        'SUM(${db.saleItems.quantity.name} * ${db.saleItems.price.name})');

    final query = db.select(db.saleItems).join([
      innerJoin(db.products, db.products.id.equalsExp(db.saleItems.productId)),
      innerJoin(db.sales, db.sales.id.equalsExp(db.saleItems.saleId)),
    ])
      ..where(db.sales.createdAt.isBiggerOrEqual(Variable(monthStart)))
      ..addColumns([quantitySum, revenueSum])
      ..groupBy([db.saleItems.productId])
      ..orderBy([OrderingTerm.desc(revenueSum)])
      ..limit(limit);

    final rows = await query.get();

    return rows.map((row) {
      final product = row.readTable(db.products);
      return TopProduct(
        id: product.id,
        name: product.name,
        revenue: (row.read(revenueSum) ?? 0).toDouble(),
        quantity: (row.read(quantitySum) ?? 0).toInt(),
      );
    }).toList();
  }

  Future<List<CategorySales>> getSalesByCategory() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final revenueSum = CustomExpression<double>(
        'SUM(${db.saleItems.quantity.name} * ${db.saleItems.price.name})');

    final query = db.select(db.saleItems).join([
      innerJoin(db.sales, db.sales.id.equalsExp(db.saleItems.saleId)),
      innerJoin(db.products, db.products.id.equalsExp(db.saleItems.productId)),
      leftOuterJoin(
          db.categories, db.categories.id.equalsExp(db.products.categoryId)),
    ])
      ..where(db.sales.createdAt.isBiggerOrEqual(Variable(monthStart)))
      ..addColumns([revenueSum])
      ..groupBy([db.categories.name]);

    final rows = await query.get();
    final total = rows.fold<double>(
        0, (sum, row) => sum + (row.read(revenueSum) ?? 0).toDouble());

    return rows.map((row) {
      final amount = (row.read(revenueSum) ?? 0).toDouble();
      final categoryName = row.read(db.categories.name) ?? 'غير مصنف';
      return CategorySales(
        categoryName: categoryName,
        amount: amount,
        percentage: total > 0 ? (amount / total) * 100 : 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  Future<Map<String, dynamic>> getProfitSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final query = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(monthStart)));
    final sales = await query.get();

    double totalRevenue = 0;
    double totalCost = 0;

    for (var sale in sales) {
      final items = await (db.select(db.saleItems)
            ..where((t) => t.saleId.equals(sale.id)))
          .get();

      for (var item in items) {
        final products = await (db.select(db.products)
              ..where((t) => t.id.equals(item.productId)))
            .get();

        if (products.isNotEmpty) {
          final product = products.first;
          totalRevenue += (item.price * item.quantity).toDouble();
          totalCost += (product.buyPrice * item.quantity).toDouble();
        }
      }
    }

    return {
      'revenue': totalRevenue,
      'cost': totalCost,
      'profit': totalRevenue - totalCost,
      'margin': totalRevenue > 0
          ? ((totalRevenue - totalCost) / totalRevenue) * 100
          : 0,
    };
  }
}
