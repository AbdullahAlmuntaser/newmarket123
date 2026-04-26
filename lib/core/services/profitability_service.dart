import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ProfitabilityReport {
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double profitMargin;

  ProfitabilityReport({
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.profitMargin,
  });
}

class ProfitabilityService {
  final AppDatabase db;

  ProfitabilityService(this.db);

  Future<ProfitabilityReport> getGrossProfitReport(
    DateTime start,
    DateTime end,
  ) async {
    // 1. Get all posted sales in the range
    final sales =
        await (db.select(db.sales)
              ..where((s) => s.createdAt.isBetweenValues(start, end))
              ..where((s) => s.status.equals('POSTED')))
            .get();

    double totalRevenue = 0;
    double totalCost = 0;

    for (var sale in sales) {
      totalRevenue += sale.total;

      // 2. Get items for this sale and calculate COGS
      final items = await (db.select(
        db.saleItems,
      )..where((si) => si.saleId.equals(sale.id))).get();

      for (var item in items) {
        // Fallback: Use product average cost as cost price if batch is not available
        final product = await (db.select(
          db.products,
        )..where((p) => p.id.equals(item.productId))).getSingle();
        totalCost += (item.quantity * item.unitFactor) * (product.buyPrice);
      }
    }

    final grossProfit = totalRevenue - totalCost;
    final profitMargin = totalRevenue > 0
        ? (grossProfit / totalRevenue) * 100
        : 0.0;

    return ProfitabilityReport(
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      grossProfit: grossProfit,
      profitMargin: profitMargin,
    );
  }
}
