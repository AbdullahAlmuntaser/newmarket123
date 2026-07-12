import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/constants/account_codes.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class StockOperationService {
  final AppDatabase db;
  final AuditService _auditService;
  final AppConfigService _configService;

  StockOperationService(this.db, this._auditService, this._configService);

  Future<void> performInventoryAudit({
    required InventoryAuditsCompanion auditCompanion,
    required List<InventoryAuditItemsCompanion> items,
    String? userId,
  }) async {
    await db.transaction(() async {
      final auditRow =
          await db.into(db.inventoryAudits).insertReturning(auditCompanion);
      final auditId = auditRow.id;

      Decimal totalInventoryAdjustmentValue = Decimal.zero;

      for (var item in items) {
        final productId = item.productId.value;
        final actualStock = item.actualStock.value;

        final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
            .getSingle();
        final systemStockDecimal = product.stock;
        final actualStockDecimal = Decimal.parse(actualStock.toString());
        final differenceDecimal = actualStockDecimal - systemStockDecimal;

        await db.into(db.inventoryAuditItems).insert(
              item.copyWith(
                auditId: drift.Value(auditId),
                systemStock: drift.Value(systemStockDecimal),
                difference: drift.Value(differenceDecimal),
              ),
            );

        if (differenceDecimal != Decimal.zero) {
          await (db.update(db.products)
            ..where((p) => p.id.equals(productId)))
              .write(
                  ProductsCompanion(stock: drift.Value(actualStockDecimal)));

          if (differenceDecimal < Decimal.zero) {
            Decimal remainingToDeduct = differenceDecimal.abs();
            final batches = await (db.select(db.productBatches)
                  ..where((b) =>
                      b.productId.equals(productId) &
                      b.quantity.isBiggerThan(
                          drift.Constant(Decimal.zero.toString())))
                  ..orderBy([
                    (b) => drift.OrderingTerm(
                          expression: b.createdAt,
                          mode: drift.OrderingMode.asc,
                        ),
                  ]))
                .get();

            for (var batch in batches) {
              if (remainingToDeduct <= Decimal.zero) break;
              final Decimal deductFromThisBatch =
                  batch.quantity >= remainingToDeduct
                      ? remainingToDeduct
                      : batch.quantity;

              await (db.update(db.productBatches)
                ..where((b) => b.id.equals(batch.id)))
                  .write(
                ProductBatchesCompanion(
                  quantity:
                      drift.Value(batch.quantity - deductFromThisBatch),
                ),
              );
              remainingToDeduct -= deductFromThisBatch;
              totalInventoryAdjustmentValue -=
                  deductFromThisBatch * batch.costPrice;
            }
          } else {
            final defaultWarehouseId =
                await _configService.getDefaultWarehouseId();
            const uuid = Uuid();
            final averageCost = product.buyPrice;
            await db.into(db.productBatches).insert(
                  ProductBatchesCompanion(
                    id: drift.Value(uuid.v4()),
                    productId: drift.Value(productId),
                    warehouseId: drift.Value(defaultWarehouseId),
                    batchNumber:
                        drift.Value('AUDIT-${auditId.substring(0, 8)}'),
                    expiryDate: const drift.Value(null),
                    quantity: drift.Value(differenceDecimal),
                    initialQuantity: drift.Value(differenceDecimal),
                    costPrice: drift.Value(averageCost),
                  ),
                );
            totalInventoryAdjustmentValue +=
                differenceDecimal * averageCost;
          }
        }
      }

      if (totalInventoryAdjustmentValue != Decimal.zero) {
        await _postInventoryAdjustment(
          totalInventoryAdjustmentValue,
          auditId,
        );
      }

      await _auditService.log(
        action: 'INVENTORY_AUDIT',
        targetEntity: 'InventoryAudits',
        entityId: auditId,
        userId: userId,
        details:
            'Performed inventory audit with total value adjustment: $totalInventoryAdjustmentValue',
      );
    });
  }

  Future<void> _postInventoryAdjustment(
    Decimal value,
    String referenceId,
  ) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final inventoryAccount =
        await dao.getAccountByCode(AccountCodes.inventory);
    final adjustmentAccount =
        await dao.getAccountByCode(AccountCodes.cashOverShort);

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
    if (value > Decimal.zero) {
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: inventoryAccount.id,
        debit: drift.Value(value.abs()),
        credit: drift.Value(Decimal.zero),
      ));
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: adjustmentAccount.id,
        debit: drift.Value(Decimal.zero),
        credit: drift.Value(value.abs()),
      ));
    } else {
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: adjustmentAccount.id,
        debit: drift.Value(value.abs()),
        credit: drift.Value(Decimal.zero),
      ));
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: inventoryAccount.id,
        debit: drift.Value(Decimal.zero),
        credit: drift.Value(value.abs()),
      ));
    }

    await dao.createEntry(entry, lines);
  }

  Future<void> deductStock({
    required String itemId,
    required Decimal quantity,
    required String warehouseId,
    String? referenceId,
    String? userId,
  }) async {
    await db.transaction(() async {
      final product = await (db.select(db.products)
        ..where((p) => p.id.equals(itemId)))
          .getSingle();

      final allowNegative = await _configService.getBool(
          'allow_negative_stock', defaultValue: false);

      if (!allowNegative && product.stock < quantity) {
        throw Exception(
            'الرصيد الحالي (${product.stock}) غير كافٍ لخصم الكمية ($quantity). العملية مرفوضة.');
      }

      final newStock = product.stock - quantity;

      await (db.update(db.products)
        ..where((p) => p.id.equals(itemId)))
          .write(ProductsCompanion(stock: drift.Value(newStock)));

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: itemId,
              quantity: -quantity,
              type: 'SALE',
              referenceId: drift.Value(referenceId),
              transactionId: drift.Value(userId),
            ),
          );

      if (allowNegative && newStock < Decimal.zero) {
        await _auditService.log(
          action: 'NEGATIVE_STOCK_ALLOWED',
          targetEntity: 'Products',
          entityId: itemId,
          userId: userId ?? 'SYSTEM',
          details:
              'تم خصم الكمية $quantity والرصيد أصبح $newStock (مسموح حسب الإعدادات)',
        );
      }
    });
  }

  Future<void> transferStock({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<StockTransferItemsCompanion> items,
    String? note,
    String? userId,
  }) async {
    await db.transaction(() async {
      final transferId = const Uuid().v4();

      await db.into(db.stockTransfers).insert(
            StockTransfersCompanion.insert(
              id: drift.Value(transferId),
              fromWarehouseId: fromWarehouseId,
              toWarehouseId: toWarehouseId,
              transferDate: drift.Value(DateTime.now()),
              note: drift.Value(note),
              status: const drift.Value('COMPLETED'),
            ),
          );

      for (var itemCompanion in items) {
        final productId = itemCompanion.productId.value;
        final batchId = itemCompanion.batchId.value;
        final qty = itemCompanion.quantity.value;

        final sourceBatch = await (db.select(db.productBatches)
              ..where((b) => b.id.equals(batchId)))
            .getSingle();

        final qtyDecimal = Decimal.parse(qty.toString());
        if (sourceBatch.quantity < qtyDecimal) {
          throw Exception(
              'الكمية غير كافية في الدفعة المصدر لمستودع ${sourceBatch.warehouseId}');
        }

        await (db.update(db.productBatches)
          ..where((b) => b.id.equals(batchId)))
            .write(ProductBatchesCompanion(
                quantity: drift.Value(sourceBatch.quantity - qtyDecimal)));

        final targetBatch = await (db.select(db.productBatches)
              ..where((b) =>
                  b.productId.equals(productId) &
                  b.warehouseId.equals(toWarehouseId) &
                  b.batchNumber.equals(sourceBatch.batchNumber)))
            .getSingleOrNull();

        if (targetBatch != null) {
          await (db.update(db.productBatches)
            ..where((b) => b.id.equals(targetBatch.id)))
              .write(ProductBatchesCompanion(
                  quantity: drift.Value(targetBatch.quantity + qtyDecimal)));
        } else {
          await db.into(db.productBatches).insert(
                ProductBatchesCompanion.insert(
                  productId: productId,
                  warehouseId: toWarehouseId,
                  batchNumber: sourceBatch.batchNumber,
                  expiryDate: drift.Value(sourceBatch.expiryDate),
                  quantity: drift.Value(qtyDecimal),
                  initialQuantity: drift.Value(qtyDecimal),
                  costPrice: drift.Value(sourceBatch.costPrice),
                ),
              );
        }

        await db.into(db.stockTransferItems).insert(
              itemCompanion.copyWith(transferId: drift.Value(transferId)),
            );

        await db.into(db.inventoryTransactions).insert(
              InventoryTransactionsCompanion.insert(
                productId: productId,
                warehouseId: fromWarehouseId,
                batchId: drift.Value(batchId),
                quantity: drift.Value(-qty),
                type: 'TRANSFER_OUT',
                referenceId: transferId,
              ),
            );

        final targetBatchId = targetBatch?.id ?? const Uuid().v4();
        await db.into(db.inventoryTransactions).insert(
              InventoryTransactionsCompanion.insert(
                productId: productId,
                warehouseId: toWarehouseId,
                batchId: drift.Value(targetBatchId),
                quantity: drift.Value(qty),
                type: 'TRANSFER_IN',
                referenceId: transferId,
              ),
            );
      }

      await _auditService.log(
        action: 'STOCK_TRANSFER',
        targetEntity: 'StockTransfers',
        entityId: transferId,
        userId: userId,
        details:
            'Transferred stock from $fromWarehouseId to $toWarehouseId',
      );
    });
  }
}
