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

    // Grouping by supplier if possible, here simplified to create one order per supplier found
    final suppliers = await db.select(db.suppliers).get();

    for (var supplier in suppliers) {
      final itemsToOrder = lowStockProducts
          .where((p) => true)
          .toList(); // Simplified logic
      if (itemsToOrder.isEmpty) continue;

      final orderId = const Uuid().v4();
      await db.transaction(() async {
        await db
            .into(db.purchaseOrders)
            .insert(
              PurchaseOrdersCompanion(
                id: Value(orderId),
                supplierId: Value(supplier.id),
                total: const Value(0.0),
                warehouseId: Value(warehouseId),
                status: const Value('DRAFT'),
                date: Value(DateTime.now()),
              ),
            );

        for (var product in itemsToOrder) {
          await db
              .into(db.purchaseOrderItems)
              .insert(
                PurchaseOrderItemsCompanion(
                  orderId: Value(orderId),
                  productId: Value(product.id),
                  quantity: Value(
                    ((product.alertLimit - product.stock) + 10.0).toDouble(),
                  ),
                  price: Value(product.buyPrice),
                ),
              );
        }
      });
      createdOrders.add(orderId);
    }
    return createdOrders;
  }
}
