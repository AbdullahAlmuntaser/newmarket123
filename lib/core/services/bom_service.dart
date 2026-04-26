import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';

/// خدمة التصنيع (Bill of Materials)
/// مسؤولة عن تجميع المنتجات من المواد الخام
class BomService {
  final AppDatabase db;
  final AccountingService accountingService;

  BomService(this.db, this.accountingService);

  /// الحصول على قائمة المكونات لمنتج مُصنَّع
  Future<List<BillOfMaterial>> getBomForProduct(String productId) {
    return (db.select(
      db.billOfMaterials,
    )..where((tbl) => tbl.finishedProductId.equals(productId))).get();
  }

  /// الحصول على جميع وصفات التصنيع
  Future<List<BillOfMaterial>> getAllBoms() {
    return db.select(db.billOfMaterials).get();
  }

  /// إضافة مكون إلى وصفة تصنيع
  Future<void> addComponent(
    String finishedProductId,
    String componentProductId,
    double quantity,
  ) async {
    await db
        .into(db.billOfMaterials)
        .insert(
          BillOfMaterialsCompanion.insert(
            finishedProductId: finishedProductId,
            componentProductId: componentProductId,
            quantity: quantity,
          ),
        );
  }

  /// تحديث كمية مكون في وصفة
  Future<void> updateComponentQuantity(String id, double quantity) async {
    await (db.update(db.billOfMaterials)..where((tbl) => tbl.id.equals(id)))
        .write(BillOfMaterialsCompanion(quantity: Value(quantity)));
  }

  /// حذف مكون من وصفة
  Future<void> removeComponent(String id) async {
    await (db.delete(
      db.billOfMaterials,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  /// حذف جميع المكونات لمنتج مُصنَّع
  Future<void> clearBomForProduct(String productId) async {
    await (db.delete(
      db.billOfMaterials,
    )..where((tbl) => tbl.finishedProductId.equals(productId))).go();
  }

  /// تنفيذ عملية التجميع (Assembly)
  /// يستهلك المواد الخام وينتج المنتج النهائي
  /// returns: رسالة النجاح أو رمي استثناء عند الفشل
  Future<String> assemble({
    required String finishedProductId,
    required double producedQuantity,
    required String warehouseId,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    // الحصول على قائمة المكونات
    final components = await getBomForProduct(finishedProductId);
    if (components.isEmpty) {
      throw Exception('لا توجد مكونات مُعرفة لهذا المنتج');
    }

    // التحقق من توفر المخزون
    for (final component in components) {
      final requiredQty = component.quantity * producedQuantity;
      final available =
          await (db.select(db.productBatches)..where(
                (b) =>
                    b.productId.equals(component.componentProductId) &
                    b.warehouseId.equals(warehouseId) &
                    b.quantity.isBiggerThan(const Constant(0)),
              ))
              .get();

      double totalAvailable = 0;
      for (final batch in available) {
        totalAvailable += batch.quantity;
      }

      if (totalAvailable < requiredQty) {
        final productName = await _getProductName(component.componentProductId);
        throw Exception(
          'المخزون غير كافٍ: $productName — المطلوب: ${requiredQty.toStringAsFixed(2)}، المتاح: ${totalAvailable.toStringAsFixed(2)}',
        );
      }
    }

    // سحب المواد الخام بنظام FEFO
    await db.transaction(() async {
      for (final component in components) {
        final requiredQty = component.quantity * producedQuantity;
        await _consumeFromBatches(
          component.componentProductId,
          warehouseId,
          requiredQty,
          'ASSEMBLY_CONSUME',
          finishedProductId,
        );
      }

      // إضافة المنتج النهائي للمخزون
      final finalBatchNumber =
          batchNumber ?? 'ASM-${DateTime.now().millisecondsSinceEpoch}';
      final cost = await _calculateAssemblyCost(components);
      await db
          .into(db.productBatches)
          .insert(
            ProductBatchesCompanion.insert(
              productId: finishedProductId,
              warehouseId: warehouseId,
              batchNumber: finalBatchNumber,
              quantity: Value(producedQuantity),
              initialQuantity: Value(producedQuantity),
              costPrice: Value(cost),
              expiryDate: Value(expiryDate),
            ),
          );

      await db
          .into(db.inventoryTransactions)
          .insert(
            InventoryTransactionsCompanion.insert(
              productId: finishedProductId,
              warehouseId: warehouseId,
              batchId: Value(finalBatchNumber),
              quantity: producedQuantity,
              type: 'ASSEMBLY_PRODUCE',
              referenceId:
                  'ASSEMBLY-${DateTime.now().millisecondsSinceEpoch.toString()}',
            ),
          );
    });

    return 'تم تجميع $producedQuantity وحدة بنجاح';
  }

  /// استهلاك من الدفعات بنظام FEFO
  Future<void> _consumeFromBatches(
    String productId,
    String warehouseId,
    double quantity,
    String type,
    String referenceId,
  ) async {
    double remaining = quantity;

    final batches =
        await (db.select(db.productBatches)
              ..where(
                (b) =>
                    b.productId.equals(productId) &
                    b.warehouseId.equals(warehouseId) &
                    b.quantity.isBiggerThan(const Constant(0)),
              )
              ..orderBy([
                (b) => OrderingTerm.asc(b.expiryDate),
                (b) => OrderingTerm.asc(b.createdAt),
              ]))
            .get();

    for (final batch in batches) {
      if (remaining <= 0) break;

      final consumeQty = batch.quantity < remaining
          ? batch.quantity
          : remaining;
      final newQty = batch.quantity - consumeQty;
      remaining -= consumeQty;

      await (db.update(db.productBatches)..where((b) => b.id.equals(batch.id)))
          .write(ProductBatchesCompanion(quantity: Value(newQty)));

      // تسجيل حركة المخزون
      await db
          .into(db.inventoryTransactions)
          .insert(
            InventoryTransactionsCompanion.insert(
              productId: productId,
              warehouseId: warehouseId,
              batchId: Value(batch.id),
              quantity: -consumeQty,
              type: type,
              referenceId: referenceId,
            ),
          );
    }
  }

  /// حساب تكلفة التجميع
  Future<double> _calculateAssemblyCost(List<BillOfMaterial> components) async {
    double totalCost = 0;
    for (final component in components) {
      final product =
          await (db.select(db.products)
                ..where((p) => p.id.equals(component.componentProductId)))
              .getSingleOrNull();
      if (product != null) {
        totalCost += product.buyPrice * component.quantity;
      }
    }
    return totalCost;
  }

  Future<String> _getProductName(String productId) async {
    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingleOrNull();
    return product?.name ?? productId;
  }
}
