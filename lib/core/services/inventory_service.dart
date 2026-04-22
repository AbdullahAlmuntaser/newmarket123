import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

class InventoryTransactionReport {
  final InventoryTransaction transaction;
  final Product product;
  final Warehouse? warehouse;

  InventoryTransactionReport({
    required this.transaction,
    required this.product,
    this.warehouse,
  });
}

class BatchReport {
  final ProductBatch batch;
  final Product product;
  final Warehouse? warehouse;

  BatchReport({
    required this.batch,
    required this.product,
    this.warehouse,
  });
}

class InventoryService {
  final AppDatabase db;
  late final AuditService _auditService;

  InventoryService(this.db) {
    _auditService = AuditService(db);
  }

  // ==================== REPORTING ====================

  /// Report: Inventory Transactions with product and warehouse details
  Stream<List<InventoryTransactionReport>> watchInventoryTransactions({
    String? productId,
    String? warehouseId,
    int limit = 100,
  }) {
    final query = db.select(db.inventoryTransactions).join([
      drift.innerJoin(db.products, db.products.id.equalsExp(db.inventoryTransactions.productId)),
      drift.leftOuterJoin(db.warehouses, db.warehouses.id.equalsExp(db.inventoryTransactions.warehouseId)),
    ])
      ..orderBy([
        drift.OrderingTerm(expression: db.inventoryTransactions.date, mode: drift.OrderingMode.desc),
      ])
      ..limit(limit);

    if (productId != null) {
      query.where(db.inventoryTransactions.productId.equals(productId));
    }
    if (warehouseId != null) {
      query.where(db.inventoryTransactions.warehouseId.equals(warehouseId));
    }

    return query.watch().map((rows) {
      return rows.map((row) {
        return InventoryTransactionReport(
          transaction: row.readTable(db.inventoryTransactions),
          product: row.readTable(db.products),
          warehouse: row.readTableOrNull(db.warehouses),
        );
      }).toList();
    });
  }

  /// Report: Product Batches with product and warehouse details
  Stream<List<BatchReport>> watchProductBatches({
    String? productId,
    String? warehouseId,
  }) {
    final query = db.select(db.productBatches).join([
      drift.innerJoin(db.products, db.products.id.equalsExp(db.productBatches.productId)),
      drift.leftOuterJoin(db.warehouses, db.warehouses.id.equalsExp(db.productBatches.warehouseId)),
    ]);

    if (productId != null) {
      query.where(db.productBatches.productId.equals(productId));
    }
    if (warehouseId != null) {
      query.where(db.productBatches.warehouseId.equals(warehouseId));
    }

    query.orderBy([
      drift.OrderingTerm(expression: db.productBatches.createdAt, mode: drift.OrderingMode.desc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return BatchReport(
          batch: row.readTable(db.productBatches),
          product: row.readTable(db.products),
          warehouse: row.readTableOrNull(db.warehouses),
        );
      }).toList();
    });
  }

  /// Convenience: Get total inventory value (delegates to DB)
  Future<double> getTotalInventoryValue() {
    return db.calculateTotalInventoryValue();
  }

  /// Convenience: Watch low stock products (delegates to DB)
  Stream<List<Product>> watchLowStockProducts() {
    return db.watchLowStockProducts();
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
        final product = await (db.select(
          db.products,
        )..where((p) => p.id.equals(productId))).getSingle();
        final systemStock = product.stock;
        final difference = actualStock - systemStock;

        // 3. تحديث سجل الجرد بالتفاصيل المحسوبة
        await db
            .into(db.inventoryAuditItems)
            .insert(
              item.copyWith(
                auditId: drift.Value(auditId as String),
                systemStock: drift.Value(systemStock),
                difference: drift.Value(difference),
              ),
            );

        if (difference != 0) {
          // 4. تحديث كمية المنتج في جدول المنتجات
          await (db.update(db.products)..where((p) => p.id.equals(productId)))
              .write(ProductsCompanion(stock: drift.Value(actualStock)));

          // 5. تحديث الدفعات (Batches) - منطق التسوية
          if (difference < 0) {
            double remainingToDeduct = difference.abs();
            final batches =
                await (db.select(db.productBatches)
                      ..where(
                        (b) =>
                            b.productId.equals(productId) &
                            b.quantity.isBiggerThanValue(0),
                      )
                      ..orderBy([
                        (b) => drift.OrderingTerm(
                          expression: b.createdAt,
                          mode: drift.OrderingMode.asc,
                        ),
                      ]))
                    .get();

            for (var batch in batches) {
              if (remainingToDeduct <= 0) break;
              double deductFromThisBatch = batch.quantity >= remainingToDeduct
                  ? remainingToDeduct
                  : batch.quantity;

              await (db.update(
                db.productBatches,
              )..where((b) => b.id.equals(batch.id))).write(
                ProductBatchesCompanion(
                  quantity: drift.Value(batch.quantity - deductFromThisBatch),
                ),
              );
              remainingToDeduct -= deductFromThisBatch;
              totalInventoryAdjustmentValue -=
                  deductFromThisBatch * batch.costPrice;
            }
          } else {
            // فائض
            final latestBatch =
                await (db.select(db.productBatches)
                      ..where((b) => b.productId.equals(productId))
                      ..orderBy([
                        (b) => drift.OrderingTerm(
                          expression: b.createdAt,
                          mode: drift.OrderingMode.desc,
                        ),
                      ])
                      ..limit(1))
                    .getSingleOrNull();

            if (latestBatch != null) {
              await (db.update(
                db.productBatches,
              )..where((b) => b.id.equals(latestBatch.id))).write(
                ProductBatchesCompanion(
                  quantity: drift.Value(latestBatch.quantity + difference),
                ),
              );
              totalInventoryAdjustmentValue +=
                  difference * latestBatch.costPrice;
            }
          }
        }
      }

      // 6. التسوية المحاسبية (Accounting Entry)
      if (totalInventoryAdjustmentValue != 0) {
        await _postInventoryAdjustment(
          totalInventoryAdjustmentValue,
          auditId as String,
        );
      }

      // 7. توثيق العملية
      await _auditService.log(
        action: 'INVENTORY_AUDIT',
        targetEntity: 'InventoryAudits',
        entityId: auditId as String,
        userId: userId,
        details:
            'Performed inventory audit with total value adjustment: $totalInventoryAdjustmentValue',
      );
    });
  }

  Future<void> _postInventoryAdjustment(
    double value,
    String referenceId,
  ) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final inventoryAccount = await dao.getAccountByCode(
      AccountingService.codeInventory,
    );
    final adjustmentAccount = await dao.getAccountByCode(
      AccountingService.codeCashOverShort,
    ); 

    if (inventoryAccount == null || adjustmentAccount == null) {
      throw Exception('Missing GL accounts for inventory adjustment.');
    }

    final entry = GLEntriesCompanion.insert(
      id: drift.Value(entryId),
      description: 'Inventory Adjustment (Audit #$referenceId)',
      date: drift.Value(DateTime.now()),
      referenceType: const drift.Value('INVENTORY_ADJUST'),
      referenceId: drift.Value(referenceId),
    );

    List<GLLinesCompanion> lines = [];
    if (value > 0) {
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: inventoryAccount.id,
          debit: drift.Value(value.abs()),
          credit: const drift.Value(0.0),
        ),
      );
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: adjustmentAccount.id,
          debit: const drift.Value(0.0),
          credit: drift.Value(value.abs()),
        ),
      );
    } else {
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: adjustmentAccount.id,
          debit: drift.Value(value.abs()),
          credit: const drift.Value(0.0),
        ),
      );
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: inventoryAccount.id,
          debit: const drift.Value(0.0),
          credit: drift.Value(value.abs()),
        ),
      );
    }

    await dao.createEntry(entry, lines);
  }
}
