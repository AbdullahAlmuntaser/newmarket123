import 'package:supermarket/data/datasources/local/app_database.dart';

class SupplierPerformance {
  final String supplierName;
  final double totalPurchases;
  final double averagePrice;
  final int totalInvoices;

  SupplierPerformance({
    required this.supplierName,
    required this.totalPurchases,
    required this.averagePrice,
    required this.totalInvoices,
  });
}

class SupplierAnalyticsService {
  final AppDatabase db;

  SupplierAnalyticsService(this.db);

  Future<List<SupplierPerformance>> getSupplierPerformanceReport() async {
    final report = <SupplierPerformance>[];
    final suppliers = await db.select(db.suppliers).get();

    for (var supplier in suppliers) {
      final purchases = await (db.select(
        db.purchases,
      )..where((p) => p.supplierId.equals(supplier.id))).get();

      double total = 0;
      for (var p in purchases) {
        total += p.total;
      }

      report.add(
        SupplierPerformance(
          supplierName: supplier.name,
          totalPurchases: total,
          averagePrice: purchases.isNotEmpty ? total / purchases.length : 0,
          totalInvoices: purchases.length,
        ),
      );
    }

    report.sort((a, b) => b.totalPurchases.compareTo(a.totalPurchases));
    return report;
  }
}
