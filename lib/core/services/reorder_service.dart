import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class ReorderService {
  final AppDatabase db;

  ReorderService(this.db);

  /// Automatically generates purchase orders for products below their alert limits
  Future<List<String>> generateAutoPurchaseOrders({
    required String warehouseId,
  }) async {
    final List<String> createdOrders = [];

    // Find products below alert limit
    final lowStockProducts = await (db.select(
      db.products,
    )..where((p) => p.stock.isSmallerOrEqual(p.alertLimit))).get();

    if (lowStockProducts.isEmpty) return [];

    // Group products by supplier (Assuming basic link exists or is manageable)
    // For now, iterate over products and find their last supplier
    for (var product in lowStockProducts) {
      // Find last supplier for this product
      final lastPurchase = await (db.select(db.purchaseItems).join([
            innerJoin(db.purchases, db.purchases.id.equalsExp(db.purchaseItems.purchaseId)),
          ])
            ..where(db.purchaseItems.productId.equals(product.id))
            ..orderBy([OrderingTerm.desc(db.purchases.date)])
            ..limit(1))
          .getSingleOrNull();

      if (lastPurchase == null) continue;

      final supplierId = lastPurchase.readTable(db.purchases).supplierId;
      if (supplierId == null) continue;

      final orderId = const Uuid().v4();
      await db.transaction(() async {
        await db.into(db.purchaseOrders).insert(
              PurchaseOrdersCompanion(
                id: Value(orderId),
                supplierId: Value(supplierId),
                total: Value(product.buyPrice * (product.alertLimit - product.stock + 10.0)),
                warehouseId: Value(warehouseId),
                status: const Value('DRAFT'),
                date: Value(DateTime.now()),
                orderNumber: Value('AUTO-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'),
              ),
            );

        await db.into(db.purchaseOrderItems).insert(
              PurchaseOrderItemsCompanion(
                orderId: Value(orderId),
                productId: Value(product.id),
                quantity: Value(((product.alertLimit - product.stock) + 10.0).toDouble()),
                price: Value(product.buyPrice),
              ),
            );
      });
      createdOrders.add(orderId);
    }
    return createdOrders;
  }
}
