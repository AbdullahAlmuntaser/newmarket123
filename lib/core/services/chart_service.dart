import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

class ChartService {
  final AppDatabase db;

  ChartService(this.db);

  Future<List<ChartDataPoint>> getSalesTrend({int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    final result = <ChartDataPoint>[];

    for (int i = 0; i < days; i++) {
      final dayStart = startDate.add(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));

      final sales = await db.salesDao.getInvoicesByDateRange(dayStart, dayEnd);

      result.add(ChartDataPoint(
        label: '${dayStart.day}/${dayStart.month}',
        value: sales.fold(0.0, (sum, s) => sum + s.total),
      ));
    }

    return result;
  }

  Future<List<ChartDataPoint>> getCategoryDistribution() async {
    final products = await db.select(db.products).get();

    final categoryTotals = <String, double>{};

    for (var product in products) {
      final categoryId = product.categoryId ?? 'Other';
      final categories = await (db.select(db.categories)
        ..where((t) => t.id.equals(categoryId))).get();

      final categoryName = categories.isNotEmpty
          ? categories.first.name
          : 'أخرى';

      categoryTotals[categoryName] =
          (categoryTotals[categoryName] ?? 0) + product.stock.toDouble();
    }

    return categoryTotals.entries.map((e) {
      return ChartDataPoint(label: e.key, value: e.value);
    }).toList();
  }

  Future<List<ChartDataPoint>> getTopCategoriesByRevenue({int limit = 5}) async {
    final products = await db.select(db.products).get();
    final sales = await db.select(db.sales).get();

    final categoryRevenue = <String, double>{};

    for (var product in products) {
      final categoryId = product.categoryId ?? 'Other';
      final categories = await (db.select(db.categories)
        ..where((t) => t.id.equals(categoryId))).get();

      final categoryName = categories.isNotEmpty
          ? categories.first.name
          : 'أخرى';

      double revenue = 0;
      if (sales.isNotEmpty) {
        revenue += product.sellPrice * product.stock;
      }

      categoryRevenue[categoryName] =
          (categoryRevenue[categoryName] ?? 0) + revenue;
    }

    final sorted = categoryRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) {
      return ChartDataPoint(label: e.key, value: e.value);
    }).toList();
  }

  Future<List<ChartDataPoint>> getWarehouseStockDistribution() async {
    final warehouses = await db.select(db.warehouses).get();

    final result = <ChartDataPoint>[];

    for (var warehouse in warehouses) {
      final stockQuery = db.select(db.stockMovements)
        ..where((t) => Expression.or([
              t.fromWarehouseId.equals(warehouse.id),
              t.toWarehouseId.equals(warehouse.id)
            ]));
      final movements = await stockQuery.get();

      double totalStock = 0;
      for (var m in movements) {
        final qty = m.quantity;
        if (m.fromWarehouseId == warehouse.id) {
          totalStock -= qty;
        }
        if (m.toWarehouseId == warehouse.id) {
          totalStock += qty;
        }
      }

      result.add(ChartDataPoint(label: warehouse.name, value: totalStock));
    }

    return result;
  }

  Future<Map<String, dynamic>> getInventoryValueByCategory() async {
    final products = await db.select(db.products).get();

    double totalValue = 0;
    final categoryValues = <String, double>{};

    for (var product in products) {
      final value = product.stock * product.buyPrice;
      totalValue += value;

      final categoryId = product.categoryId ?? 'Other';
      final categories = await (db.select(db.categories)
        ..where((t) => t.id.equals(categoryId))).get();

      final categoryName = categories.isNotEmpty
          ? categories.first.name
          : 'أخرى';

      categoryValues[categoryName] =
          (categoryValues[categoryName] ?? 0) + value;
    }

    return {'totalValue': totalValue, 'byCategory': categoryValues};
  }
}

class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint({required this.label, required this.value});
}