import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class InventoryAuditService {
  final AppDatabase db;

  InventoryAuditService(this.db);

  Future<void> completeAudit(String auditId) async {
    await db.transaction(() async {
      final auditItems = await (db.select(db.inventoryAuditItems)
            ..where((i) => i.auditId.equals(auditId)))
          .get();

      for (var item in auditItems) {
        if (item.difference != 0) {
          await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
            productId: item.productId,
            quantity: item.difference,
            type: 'ADJUSTMENT',
            referenceId: Value(auditId),
          ));
        }
      }
    });
  }
}
