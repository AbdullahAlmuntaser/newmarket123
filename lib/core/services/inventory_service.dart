import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

class InventoryService {
  final AppDatabase db;
  late final AuditService _auditService;

  InventoryService(this.db) {
    _auditService = AuditService(db);
  }

  /// تنفيذ عملية جرد وتسوية للمخزون
  /// [auditCompanion] رأس الجرد (التاريخ، الملاحظات)
  /// [items] قائمة بالأصناف المجردة (الكمية الفعلية، معرف المنتج)
  Future<void> performInventoryAudit({
    required InventoryAuditsCompanion auditCompanion,
    required List<InventoryAuditItemsCompanion> items,
    String? userId,
  }) async {
    await db.transaction(() async {
      // 1. تسجيل رأس الجرد
      final auditId = await db.into(db.inventoryAudits).insert(auditCompanion);
      
      double totalInventoryAdjustmentValue = 0.0;

      for (var item in items) {
        final productId = item.productId.value;
        final actualStock = item.actualStock.value;

        // 2. جلب المنتج الحالي لمعرفة المخزون المسجل
        final product = await (db.select(db.products)..where((p) => p.id.equals(productId))).getSingle();
        final systemStock = product.stock;
        final difference = actualStock - systemStock;

        // 3. تحديث سجل الجرد بالتفاصيل المحسوبة
        await db.into(db.inventoryAuditItems).insert(
          item.copyWith(
            auditId: Value(auditId as String),
            systemStock: Value(systemStock),
            difference: Value(difference),
          ),
        );

        if (difference != 0) {
          // 4. تحديث كمية المنتج في جدول المنتجات
          await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
            ProductsCompanion(stock: Value(actualStock)),
          );

          // 5. تحديث الدفعات (Batches) - منطق التسوية
          // إذا كان هناك عجز (Difference < 0)، نخصم من أقدم الدفعات (FIFO)
          // إذا كان هناك فائض (Difference > 0)، نضيف للدفعة الأحدث أو ننشئ دفعة تسوية
          if (difference < 0) {
            double remainingToDeduct = difference.abs();
            final batches = await (db.select(db.productBatches)
                  ..where((b) => b.productId.equals(productId) & b.quantity.isBiggerThanValue(0))
                  ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.asc)]))
                .get();

            for (var batch in batches) {
              if (remainingToDeduct <= 0) break;
              double deductFromThisBatch = batch.quantity >= remainingToDeduct ? remainingToDeduct : batch.quantity;
              
              await (db.update(db.productBatches)..where((b) => b.id.equals(batch.id))).write(
                ProductBatchesCompanion(quantity: Value(batch.quantity - deductFromThisBatch)),
              );
              remainingToDeduct -= deductFromThisBatch;
              totalInventoryAdjustmentValue -= deductFromThisBatch * batch.costPrice;
            }
          } else {
            // فائض: نضيفه لأحدث دفعة موجودة لتبسيط العملية
            final latestBatch = await (db.select(db.productBatches)
                  ..where((b) => b.productId.equals(productId))
                  ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)])
                  ..limit(1))
                .getSingleOrNull();

            if (latestBatch != null) {
              await (db.update(db.productBatches)..where((b) => b.id.equals(latestBatch.id))).write(
                ProductBatchesCompanion(quantity: Value(latestBatch.quantity + difference)),
              );
              totalInventoryAdjustmentValue += difference * latestBatch.costPrice;
            }
          }
        }
      }

      // 6. التسوية المحاسبية (Accounting Entry)
      if (totalInventoryAdjustmentValue != 0) {
        await _postInventoryAdjustment(totalInventoryAdjustmentValue, auditId as String);
      }

      // 7. توثيق العملية
      await _auditService.log(
        action: 'INVENTORY_AUDIT',
        targetEntity: 'InventoryAudits',
        entityId: auditId as String,
        userId: userId,
        details: 'Performed inventory audit with total value adjustment: $totalInventoryAdjustmentValue',
      );
    });
  }

  Future<void> _postInventoryAdjustment(double value, String referenceId) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final inventoryAccount = await dao.getAccountByCode(AccountingService.codeInventory);
    final adjustmentAccount = await dao.getAccountByCode(AccountingService.codeCashOverShort); // يمكن استخدام حساب مخصص لتسويات المخزون

    if (inventoryAccount == null || adjustmentAccount == null) {
      throw Exception('Missing GL accounts for inventory adjustment.');
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Inventory Adjustment (Audit #$referenceId)',
      date: Value(DateTime.now()),
      referenceType: const Value('INVENTORY_ADJUST'),
      referenceId: Value(referenceId),
    );

    List<GLLinesCompanion> lines = [];
    if (value > 0) {
      // فائض: مدين مخزون، دائن تسويات (أرباح)
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: inventoryAccount.id,
        debit: Value(value.abs()),
        credit: const Value(0.0),
      ));
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: adjustmentAccount.id,
        debit: const Value(0.0),
        credit: Value(value.abs()),
      ));
    } else {
      // عجز: مدين تسويات (مصاريف)، دائن مخزون
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: adjustmentAccount.id,
        debit: Value(value.abs()),
        credit: const Value(0.0),
      ));
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: inventoryAccount.id,
        debit: const Value(0.0),
        credit: Value(value.abs()),
      ));
    }

    await dao.createEntry(entry, lines);
  }
}
