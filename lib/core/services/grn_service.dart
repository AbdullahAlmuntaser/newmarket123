import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

class GrnService {
  final AppDatabase db;
  late final AuditService _auditService;

  GrnService(this.db) {
    _auditService = AuditService(db);
  }

  Future<String> createGrn({
    required String purchaseOrderId,
    required String warehouseId,
    required List<GoodReceivedNoteItemsCompanion> items,
    String? receivedBy,
    String? notes,
    String? userId,
  }) async {
    return await db.transaction(() async {
      final grnId = const Uuid().v4();
      final grnNumber = 'GRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

      // 1. Create GRN Header
      await db.into(db.goodReceivedNotes).insert(
        GoodReceivedNotesCompanion.insert(
          id: Value(grnId),
          purchaseOrderId: purchaseOrderId,
          warehouseId: warehouseId,
          grnNumber: grnNumber,
          receivedBy: Value(receivedBy),
          notes: Value(notes),
        ),
      );

      // 2. Insert Items & Update Inventory/Batches
      for (var item in items) {
        await db.into(db.goodReceivedNoteItems).insert(
          item.copyWith(grnId: Value(grnId)),
        );

        // Update/Create Batch
        final productId = item.productId.value;
        final qty = item.quantity.value;
        
        // Simplified logic: creating a batch for the received item
        final batchId = const Uuid().v4();
        await db.into(db.productBatches).insert(
          ProductBatchesCompanion.insert(
            id: Value(batchId),
            productId: productId,
            warehouseId: warehouseId,
            batchNumber: item.batchNumber.value ?? 'BATCH-$grnNumber',
            quantity: Value(qty),
            initialQuantity: Value(qty),
            expiryDate: item.expiryDate,
          ),
        );

        // Update Product Stock
        final product = await (db.select(db.products)..where((p) => p.id.equals(productId))).getSingle();
        await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
          ProductsCompanion(stock: Value(product.stock + qty)),
        );
      }

      // 3. Log Audit
      await _auditService.log(
        action: 'CREATE_GRN',
        targetEntity: 'GoodReceivedNotes',
        entityId: grnId,
        userId: userId,
        details: 'Created GRN $grnNumber for Purchase Order $purchaseOrderId',
      );

      return grnId;
    });
  }

  Future<void> postGrn(String grnId) async {
    await db.transaction(() async {
      await (db.update(db.goodReceivedNotes)..where((t) => t.id.equals(grnId))).write(
        const GoodReceivedNotesCompanion(status: Value('POSTED')),
      );
    });
  }
}
