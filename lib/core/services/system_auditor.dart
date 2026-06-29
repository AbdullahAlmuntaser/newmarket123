import 'package:supermarket/data/datasources/local/app_database.dart';

class SystemAuditor {
  final AppDatabase db;

  SystemAuditor(this.db);

  /// Phase 10: Self-Validation Engine
  /// Checks system integrity: Inventory and Accounting balances
  Future<Map<String, dynamic>> runAudit() async {
    final results = <String, dynamic>{};

    // 1. Inventory Integrity Check: Stock vs Sum(Batches)
    final products = await db.select(db.products).get();
    bool inventoryOk = true;
    for (var product in products) {
      final batches = await (db.select(
        db.productBatches,
      )..where((b) => b.productId.equals(product.id)))
          .get();
      final Decimal batchSum =
          batches.fold<Decimal>(Decimal.zero, (sum, b) => sum + b.quantity);
      if ((product.stock - batchSum).abs() > Decimal.parse('0.001')) {
        inventoryOk = false;
        break;
      }
    }
    results['inventory_integrity'] = inventoryOk;

    // 2. Accounting Integrity Check: Balanced Journals
    final entries = await db.select(db.gLEntries).get();
    bool accountingOk = true;
    for (var entry in entries) {
      final lines = await (db.select(
        db.gLLines,
      )..where((l) => l.entryId.equals(entry.id)))
          .get();
      double debit = lines.fold(0, (sum, l) => sum + l.debit.toDouble());
      double credit = lines.fold(0, (sum, l) => sum + l.credit.toDouble());
      if ((debit - credit).abs() > 0.01) {
        accountingOk = false;
        break;
      }
    }
    results['accounting_integrity'] = accountingOk;

    return results;
  }
}
