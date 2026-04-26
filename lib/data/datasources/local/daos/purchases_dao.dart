import 'package:drift/drift.dart';
import '../app_database.dart';

part 'purchases_dao.g.dart';

@DriftAccessor(
  tables: [
    Purchases,
    PurchaseItems,
    PurchaseOrders,
    PurchaseOrderItems,
    Products,
    Suppliers,
    SyncQueue,
    AuditLogs,
    ProductBatches,
    PurchaseReturns,
    PurchaseReturnItems,
  ],
)
class PurchasesDao extends DatabaseAccessor<AppDatabase>
    with _$PurchasesDaoMixin {
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

  Future<PurchaseItem?> getLastPurchaseItem(
    String productId, {
    String? supplierId,
  }) async {
    final query = select(purchaseItems).join([
      innerJoin(purchases, purchases.id.equalsExp(purchaseItems.purchaseId)),
    ])..where(purchaseItems.productId.equals(productId));

    if (supplierId != null) {
      query.where(purchases.supplierId.equals(supplierId));
    }

    query.orderBy([OrderingTerm.desc(purchases.date)]);

    final results = await query.get();
    if (results.isEmpty) return null;
    final row = results.first;
    return row.readTable(purchaseItems);
  }

  Future<Purchase?> getLastPurchase(
    String productId, {
    String? supplierId,
  }) async {
    final query = select(purchases).join([
      innerJoin(
        purchaseItems,
        purchaseItems.purchaseId.equalsExp(purchases.id),
      ),
    ])..where(purchaseItems.productId.equals(productId));

    if (supplierId != null) {
      query.where(purchases.supplierId.equals(supplierId));
    }

    query.orderBy([OrderingTerm.desc(purchases.date)]);

    final results = await query.get();
    if (results.isEmpty) return null;
    final row = results.first;
    return row.readTable(purchases);
  }

  Future<double?> getBestPurchasePrice(String productId) async {
    final query = selectOnly(purchaseItems)
      ..addColumns([purchaseItems.unitPrice.min()])
      ..where(purchaseItems.productId.equals(productId));

    final row = await query.getSingle();
    return row.read(purchaseItems.unitPrice.min());
  }

  // --- Purchase Orders ---
  Stream<List<PurchaseOrder>> watchAllPurchaseOrders() {
    return (select(purchaseOrders)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(String orderId) {
    return (select(
      purchaseOrderItems,
    )..where((pi) => pi.orderId.equals(orderId))).get();
  }

  Future<void> createPurchaseOrder({
    required PurchaseOrdersCompanion orderCompanion,
    required List<PurchaseOrderItemsCompanion> itemsCompanions,
  }) async {
    return transaction(() async {
      await into(purchaseOrders).insert(orderCompanion);
      for (var item in itemsCompanions) {
        await into(purchaseOrderItems).insert(item);
      }
    });
  }

  Future<void> updatePurchaseOrderStatus(String orderId, String status) async {
    await (update(purchaseOrders)..where((t) => t.id.equals(orderId))).write(
      PurchaseOrdersCompanion(status: Value(status)),
    );
  }
}
