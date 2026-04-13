import 'package:drift/drift.dart';
import '../app_database.dart';

part 'purchases_dao.g.dart';

@DriftAccessor(
  tables: [
    Purchases,
    PurchaseItems,
    Products,
    Suppliers,
    SyncQueue,
    AuditLogs,
    ProductBatches,
    PurchaseReturns,
    PurchaseReturnItems,
  ],
)
class PurchasesDao extends DatabaseAccessor<AppDatabase> with _$PurchasesDaoMixin {
  PurchasesDao(super.db);

  Stream<List<Purchase>> watchAllPurchases() => select(purchases).watch();

  Stream<List<PurchaseItem>> watchPurchaseItems(String purchaseId) {
    return (select(
      purchaseItems,
    )..where((pi) => pi.purchaseId.equals(purchaseId))).watch();
  }

  Future<Purchase?> getPurchaseById(String id) {
    return (select(purchases)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<List<PurchaseReturn>> watchAllPurchaseReturns() {
    return (select(purchaseReturns)..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Stream<List<PurchaseReturnItem>> watchPurchaseReturnItems(String returnId) {
    return (select(
      purchaseReturnItems,
    )..where((pi) => pi.purchaseReturnId.equals(returnId))).watch();
  }

  Future<void> createPurchase({
    required PurchasesCompanion purchaseCompanion,
    required List<PurchaseItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    if (itemsCompanions.isEmpty) {
      throw Exception('لا يمكن إنشاء فاتورة مشتريات بدون أصناف.');
    }

    return transaction(() async {
      // 1. Insert Purchase
      final purchaseId = purchaseCompanion.id.value;
      await into(purchases).insert(purchaseCompanion);

      // 2. Insert Items
      for (var item in itemsCompanions) {
        await into(purchaseItems).insert(item);
      }

      // 3. Audit Log
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'PURCHASES',
          entityId: purchaseId,
          details: Value('Created purchase record: $purchaseId'),
        ),
      );
    });
  }

  Future<void> createPurchaseReturn({
    required PurchaseReturnsCompanion returnCompanion,
    required List<PurchaseReturnItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    return transaction(() async {
      // 1. Insert Purchase Return
      final returnId = returnCompanion.id.value;
      await into(purchaseReturns).insert(returnCompanion);

      // 2. Insert Items
      for (var item in itemsCompanions) {
        await into(purchaseReturnItems).insert(item);
      }

      // 3. Audit Log
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'PURCHASE_RETURNS',
          entityId: returnId,
          details: Value(
            'Created purchase return record: $returnId for purchase: ${returnCompanion.purchaseId.value}',
          ),
        ),
      );
    });
  }
}
