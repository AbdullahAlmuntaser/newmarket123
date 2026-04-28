import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

class StockTransferService {
  final AppDatabase db;
  late final AuditService _auditService;

  StockTransferService(this.db) {
    _auditService = AuditService(db);
  }

  Future<void> processTransfer({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<TransferItemData> items,
    String? note,
    String? userId,
  }) async {
    if (fromWarehouseId == toWarehouseId) {
      throw Exception('Source and destination warehouses must be different.');
    }

    await db.transaction(() async {
      final transferId = const Uuid().v4();

      // 1. Record Transfer Header
      await db
          .into(db.stockTransfers)
          .insert(
            StockTransfersCompanion.insert(
              id: Value(transferId),
              fromWarehouseId: fromWarehouseId,
              toWarehouseId: toWarehouseId,
              transferDate: Value(DateTime.now()),
              note: Value(note),
              status: const Value('COMPLETED'),
            ),
          );

      for (var item in items) {
        // 2. Get Source Batch
        final sourceBatch = await (db.select(
          db.productBatches,
        )..where((t) => t.id.equals(item.batchId))).getSingle();

        if (sourceBatch.quantity < item.quantity) {
          throw Exception(
            'Insufficient stock in batch ${sourceBatch.batchNumber} for product ${item.productId}',
          );
        }

        // 3. Update Source Batch (Deduct)
        await (db.update(
          db.productBatches,
        )..where((t) => t.id.equals(sourceBatch.id))).write(
          ProductBatchesCompanion(
            quantity: Value(sourceBatch.quantity - item.quantity),
          ),
        );
        
        // Record Deduct Transaction
        await db.into(db.inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: item.productId,
            warehouseId: fromWarehouseId,
            batchId: Value(item.batchId),
            quantity: -item.quantity,
            type: 'TRANSFER_OUT',
            referenceId: transferId,
          ),
        );

        // 4. Create or Update Destination Batch
        final existingDestBatch =
            await (db.select(db.productBatches)
                  ..where(
                    (t) =>
                        t.productId.equals(item.productId) &
                        t.warehouseId.equals(toWarehouseId) &
                        t.batchNumber.equals(sourceBatch.batchNumber),
                  )
                  ..limit(1))
                .getSingleOrNull();

        String destBatchId;
        if (existingDestBatch != null) {
          destBatchId = existingDestBatch.id;
          await (db.update(
            db.productBatches,
          )..where((t) => t.id.equals(destBatchId))).write(
            ProductBatchesCompanion(
              quantity: Value(existingDestBatch.quantity + item.quantity),
            ),
          );
        } else {
          destBatchId = const Uuid().v4();
          await db
              .into(db.productBatches)
              .insert(
                ProductBatchesCompanion.insert(
                  id: Value(destBatchId),
                  productId: item.productId,
                  warehouseId: toWarehouseId,
                  batchNumber: sourceBatch.batchNumber,
                  expiryDate: Value(sourceBatch.expiryDate),
                  quantity: Value(item.quantity),
                  initialQuantity: Value(item.quantity),
                  costPrice: Value(sourceBatch.costPrice),
                ),
              );
        }
        
        // Record Add Transaction
        await db.into(db.inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: item.productId,
            warehouseId: toWarehouseId,
            batchId: Value(destBatchId),
            quantity: item.quantity,
            type: 'TRANSFER_IN',
            referenceId: transferId,
          ),
        );

        // 5. Record Transfer Item
        await db
            .into(db.stockTransferItems)
            .insert(
              StockTransferItemsCompanion.insert(
                id: Value(const Uuid().v4()),
                transferId: transferId,
                productId: item.productId,
                batchId: item.batchId,
                quantity: item.quantity,
              ),
            );
      }

      // 6. Log Audit
      await _auditService.log(
        action: 'STOCK_TRANSFER',
        targetEntity: 'StockTransfers',
        entityId: transferId,
        userId: userId,
        details: 'Transferred ${items.length} items from $fromWarehouseId to $toWarehouseId',
      );
    });
  }

  Future<List<Warehouse>> getAllWarehouses() async {
    return await db.select(db.warehouses).get();
  }

  Future<List<ProductBatch>> getBatchesForWarehouse(String warehouseId) async {
    return await (db.select(db.productBatches)..where(
          (t) =>
              t.warehouseId.equals(warehouseId) &
              t.quantity.isBiggerThan(const Variable(0)),
        ))
        .get();
  }
}

class TransferItemData {
  final String productId;
  final String batchId;
  final double quantity;

  TransferItemData({
    required this.productId,
    required this.batchId,
    required this.quantity,
  });
}
