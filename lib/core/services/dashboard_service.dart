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
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    
    final salesQuery = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(todayStart)));
    final todaySalesList = await salesQuery.get();
    double todaySales = todaySalesList.fold(0.0, (sum, item) => sum + item.total);
    int todayTransactions = todaySalesList.length;

    final weekSalesQuery = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(weekStart)));
    final weekSalesList = await weekSalesQuery.get();
    double weeklySales = weekSalesList.fold(0.0, (sum, item) => sum + item.total);

    final monthSalesQuery = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(monthStart)));
    final monthSalesList = await monthSalesQuery.get();
    double monthlySales = monthSalesList.fold(0.0, (sum, item) => sum + item.total);

    final purchasesQuery = db.select(db.purchases)
      ..where((t) => t.date.isBiggerOrEqual(Variable(todayStart)));
    final purchases = await purchasesQuery.get();
    double totalPurchases = purchases.fold(0.0, (sum, item) => sum + item.total);

    final cashAccount = await db.accountingDao.getAccountByCode('1010');
    double cashBalance = 0;
    if (cashAccount != null) {
      cashBalance = await db.accountingDao.getAccountBalance(cashAccount.id);
    }

    final lowStock = await (db.select(db.products)
      ..where((t) => t.stock.isSmallerOrEqual(t.alertLimit))).get();

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
      
      final daySales = await db.salesDao.getInvoicesByDateRange(dayStart, dayEnd);

      result.add(SalesDataPoint(
        date: dayStart,
        amount: daySales.fold(0.0, (sum, s) => sum + s.total),
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

      final daySales = await db.salesDao.getInvoicesByDateRange(dayStart, dayEnd);

      result.add(SalesDataPoint(
        date: dayStart,
        amount: daySales.fold(0.0, (sum, s) => sum + s.total),
        count: daySales.length,
      ));
    }

    return result;
  }

  Future<List<TopProduct>> getTopProducts({int limit = 5}) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    final query = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(monthStart)));
    final sales = await query.get();
    
    final productTotals = <String, Map<String, dynamic>>{};
    
    for (var sale in sales) {
      final items = await (db.select(db.saleItems)
        ..where((t) => t.saleId.equals(sale.id))).get();
      
      for (var item in items) {
        if (!productTotals.containsKey(item.productId)) {
          productTotals[item.productId] = {'revenue': 0.0, 'quantity': 0};
        }
        productTotals[item.productId]!['revenue'] += item.price * item.quantity;
        productTotals[item.productId]!['quantity'] += item.quantity;
      }
    }
    
    final sortedProducts = productTotals.entries.toList()
      ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));
    
    final topProducts = <TopProduct>[];
    
    for (var i = 0; i < sortedProducts.length && i < limit; i++) {
      final entry = sortedProducts[i];
      final products = await (db.select(db.products)
        ..where((t) => t.id.equals(entry.key))).get();
      
      if (products.isNotEmpty) {
        final product = products.first;
        topProducts.add(TopProduct(
          id: entry.key,
          name: product.name,
          revenue: entry.value['revenue'] as double,
          quantity: entry.value['quantity'] as int,
        ));
      }
    }
    
    return topProducts;
  }

  Future<List<CategorySales>> getSalesByCategory() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final query = db.select(db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqual(Variable(monthStart)));
    final sales = await query.get();

    final categoryTotals = <String, double>{};

    for (var sale in sales) {
      final items = await (db.select(db.saleItems)
        ..where((t) => t.saleId.equals(sale.id))).get();

      for (var item in items) {
        final products = await (db.select(db.products)
          ..where((t) => t.id.equals(item.productId))).get();

        if (products.isNotEmpty) {
          final product = products.first;
          final categoryId = product.categoryId ?? 'Uncategorized';

          final categories = await (db.select(db.categories)
            ..where((t) => t.id.equals(categoryId))).get();

          final categoryName = categories.isNotEmpty
              ? categories.first.name
              : 'غير مصنف';

          categoryTotals[categoryName] =
              (categoryTotals[categoryName] ?? 0) + (item.price * item.quantity);
        }
      }
    }

    final total = categoryTotals.values.fold(0.0, (sum, v) => sum + v);

    return categoryTotals.entries.map((e) {
      return CategorySales(
        categoryName: e.key,
        amount: e.value,
        percentage: total > 0 ? (e.value / total) * 100 : 0,
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
        ..where((t) => t.saleId.equals(sale.id))).get();
      
      for (var item in items) {
        final products = await (db.select(db.products)
          ..where((t) => t.id.equals(item.productId))).get();
        
        if (products.isNotEmpty) {
          final product = products.first;
          totalRevenue += item.price * item.quantity;
          totalCost += product.buyPrice * item.quantity;
        }
      }
    }
    
    return {
      'revenue': totalRevenue,
      'cost': totalCost,
      'profit': totalRevenue - totalCost,
      'margin': totalRevenue > 0 ? ((totalRevenue - totalCost) / totalRevenue) * 100 : 0,
    };
  }
}