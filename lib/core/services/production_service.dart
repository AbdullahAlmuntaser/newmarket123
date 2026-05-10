import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class ProductionService {
  final AppDatabase db;

  ProductionService(this.db);

  Future<void> createProductionOrder({
    required String finishedProductId,
    required double quantity,
    String? warehouseId,
    String? note,
  }) async {
    await db.transaction(() async {
      final orderId = const Uuid().v4();
      
      // 1. Get BOM for this product
      final bom = await (db.select(db.billOfMaterials)
            ..where((t) => t.finishedProductId.equals(finishedProductId)))
          .get();

      if (bom.isEmpty) throw Exception('No BOM found for this product');

      // 2. Create Order
      await db.into(db.productionOrders).insert(
        ProductionOrdersCompanion.insert(
          id: Value(orderId),
          finishedProductId: finishedProductId,
          plannedQuantity: quantity,
          warehouseId: Value(warehouseId),
          note: Value(note),
        ),
      );

      // 3. Create Order Items from BOM
      for (var item in bom) {
        await db.into(db.productionOrderItems).insert(
          ProductionOrderItemsCompanion.insert(
            productionOrderId: orderId,
            componentProductId: item.componentProductId,
            plannedQuantity: item.quantity * quantity,
          ),
        );
      }
    });
  }

  Future<void> completeProductionOrder(String orderId) async {
    await db.transaction(() async {
      final order = await (db.select(db.productionOrders)..where((t) => t.id.equals(orderId))).getSingle();
      final items = await (db.select(db.productionOrderItems)..where((t) => t.productionOrderId.equals(orderId))).get();

      // 1. Consume Raw Materials
      for (var item in items) {
        await db.stockMovementDao.insertStockMovement(
          StockMovementsCompanion.insert(
            productId: item.componentProductId,
            quantity: -item.plannedQuantity,
            type: 'PRODUCTION_CONSUME',
            referenceId: Value(orderId),
            movementDate: Value(DateTime.now()),
          ),
        );
      }

      // 2. Produce Finished Good
      await db.stockMovementDao.insertStockMovement(
        StockMovementsCompanion.insert(
          productId: order.finishedProductId,
          quantity: order.plannedQuantity,
          type: 'PRODUCTION_OUTPUT',
          referenceId: Value(orderId),
          movementDate: Value(DateTime.now()),
        ),
      );

      // 3. Update Order Status
      await (db.update(db.productionOrders)..where((t) => t.id.equals(orderId))).write(
        ProductionOrdersCompanion(
          status: const Value('COMPLETED'),
          actualQuantity: Value(order.plannedQuantity),
        ),
      );
    });
  }

}
