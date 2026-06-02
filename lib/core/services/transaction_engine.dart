import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/core/services/cash_management_service.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

class TransactionEngine {
  final AppDatabase db;
  final EventBusService eventBus;
  late final AuditService _auditService;
  late final AppConfigService _configService;
  final AccountingService _accountingService;
  InventoryCostingService? _costingService;

  TransactionEngine(this.db, this.eventBus, this._accountingService) {
    _auditService = AuditService(db);
    _configService = AppConfigService(db);
  }

  void setCostingService(InventoryCostingService costingService) {
    _costingService = costingService;
  }

  Future<void> _checkAccountingPeriodOpen() async {
    final now = DateTime.now();
    final openPeriod = await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..where((p) => p.startDate.isSmallerOrEqual(Variable(now)))
          ..where((p) => p.endDate.isBiggerOrEqual(Variable(now))))
        .getSingleOrNull();

    if (openPeriod == null) {
      throw Exception(
        'لا توجد فترة محاسبية مفتوحة حالياً. يرجى فتح فترة محاسبية جديدة.',
      );
    }
  }

  Future<void> postPurchase(String purchaseId, {String? userId}) async {
    if (purchaseId.isEmpty) {
      throw Exception('معرف الفاتورة غير صالح.');
    }

    await _checkAccountingPeriodOpen();

    try {
      await db.transaction(() async {
        final purchase = await (db.select(
          db.purchases,
        )..where((p) => p.id.equals(purchaseId)))
            .getSingle();

        if (purchase.isCredit && purchase.supplierId == null) {
          throw Exception('يجب اختيار مورد لفاتورة الشراء الآجل.');
        }

        if (purchase.status == DocumentStatus.received) {
          throw Exception('هذه الفاتورة تم استلامها بالفعل.');
        }

        final items = await (db.select(
          db.purchaseItems,
        )..where((pi) => pi.purchaseId.equals(purchaseId)))
            .get();

        if (items.isEmpty) {
          throw Exception('لا يمكن ترحيل فاتورة مشتريات بدون أصناف.');
        }

        Decimal subtotal = Decimal.zero;
        for (var item in items) {
          if (item.quantity <= Decimal.zero) {
            throw Exception('كمية الشراء يجب أن تكون أكبر من الصفر.');
          }
          subtotal += item.quantity * item.price;
        }

        for (var item in items) {
          Decimal itemValue = item.quantity * item.price;
          Decimal proportion = subtotal > Decimal.zero ? (itemValue / subtotal).toDecimal() : Decimal.zero;
          Decimal allocatedLandedCost = purchase.landedCosts * proportion;
          Decimal landedCostPerUnit =
              item.quantity > Decimal.zero ? (allocatedLandedCost / item.quantity).toDecimal() : Decimal.zero;
          Decimal finalUnitCost = item.price + landedCostPerUnit;

          final product = await (db.select(
            db.products,
          )..where((p) => p.id.equals(item.productId)))
              .getSingle();

          Decimal qtyInBaseUnit = item.quantity * item.unitFactor;

          final batchId = const Uuid().v4();
          await db.into(db.productBatches).insert(
                ProductBatchesCompanion.insert(
                  id: Value(batchId),
                  productId: item.productId,
                  warehouseId: purchase.warehouseId ?? '',
                  batchNumber:
                      item.batchNumber != null && item.batchNumber!.isNotEmpty
                          ? item.batchNumber!
                          : 'PUR-${purchase.id.substring(0, 8)}',
                  expiryDate: Value(item.expiryDate),
                  quantity: Value(qtyInBaseUnit),
                  initialQuantity: Value(qtyInBaseUnit),
                  costPrice: Value(
                    (finalUnitCost / item.unitFactor).toDecimal(),
                  ),
                  syncStatus: const Value.absent(),
                ),
              );

          await (db.update(db.purchaseItems)
                ..where((pi) => pi.id.equals(item.id)))
              .write(PurchaseItemsCompanion(batchId: Value(batchId)));

          await db.into(db.inventoryTransactions).insert(
                InventoryTransactionsCompanion.insert(
                  productId: item.productId,
                  warehouseId: purchase.warehouseId ?? '',
                  batchId: Value(batchId),
                  quantity: qtyInBaseUnit.toDouble(),
                  type: 'PURCHASE',
                  referenceId: purchaseId,
                ),
              );

          await (db.update(
            db.products,
          )..where((p) => p.id.equals(item.productId)))
              .write(
            ProductsCompanion(
              stock: Value(product.stock + qtyInBaseUnit),
              buyPrice: Value(finalUnitCost),
            ),
          );
        }

        await (db.update(db.purchases)..where((p) => p.id.equals(purchaseId)))
            .write(const PurchasesCompanion(
                status: Value(DocumentStatus.received)));

        if (purchase.isCredit && purchase.supplierId != null) {
          final supplier = await (db.select(
            db.suppliers,
          )..where((s) => s.id.equals(purchase.supplierId!)))
              .getSingle();

          await (db.update(
            db.suppliers,
          )..where((s) => s.id.equals(supplier.id)))
              .write(
            SuppliersCompanion(
                balance: Value(supplier.balance + purchase.total)),
          );
        }

        await _accountingService.postPurchase(purchase, items);

        await _auditService.log(
          action: 'POST_PURCHASE',
          targetEntity: 'Purchases',
          entityId: purchaseId,
          userId: userId,
          details: 'Posted purchase invoice $purchaseId',
        );

        eventBus.fire(PurchasePostedEvent(purchase, items, userId: userId));
      });
    } catch (e) {
      throw Exception('خطأ في العملية: $e');
    }
  }

  Future<void> postSale(String saleId, {String? userId}) async {
    await _checkAccountingPeriodOpen();

    developer.log('postSale requested: saleId=$saleId, userId=$userId', name: 'invoice.lifecycle');

    final saleCheck = await (db.select(db.sales)
          ..where((s) => s.id.equals(saleId)))
        .getSingleOrNull();

    if (saleCheck == null) {
      throw Exception('الفاتورة غير موجودة.');
    }

    developer.log(
      'postSale pre-check: saleId=$saleId, status=${saleCheck.status.name}, payment=${saleCheck.paymentMethod.name}',
      name: 'invoice.lifecycle',
    );

    if (saleCheck.status == DocumentStatus.posted) {
      throw Exception('هذه الفاتورة تم ترحيلها بالفعل.');
    }

    if (saleCheck.paymentMethod == PaymentMethod.cash && userId != null) {
      final activeShift = await (db.select(db.shifts)
            ..where((s) => s.userId.equals(userId) & s.isOpen.equals(true)))
          .getSingleOrNull();
      if (activeShift == null) {
        throw Exception('لا يمكن إجراء عملية بيع نقدي بدون فتح وردية عمل.');
      }
    }

    await db.transaction(() async {
      final currentSale = await (db.select(db.sales)
            ..where((s) => s.id.equals(saleId))
            ..where((s) => s.status.equals(DocumentStatus.draft.index)))
          .getSingleOrNull();

      if (currentSale == null) {
        final latestSale = await (db.select(db.sales)
              ..where((s) => s.id.equals(saleId)))
            .getSingle();
        if (latestSale.status == DocumentStatus.posted) {
          throw Exception('هذه الفاتورة تم ترحيلها بالفعل.');
        }
        throw Exception('حالة الفاتورة غير صالحة للترحيل.');
      }

      final sale = currentSale;

      final items = await (db.select(
        db.saleItems,
      )..where((si) => si.saleId.equals(saleId)))
          .get();

      if (items.isEmpty) {
        throw Exception('لا يمكن ترحيل فاتورة مبيعات بدون أصناف.');
      }

      Decimal saleCogs = Decimal.zero;
      for (var item in items) {
        if (item.quantity <= Decimal.zero) {
          throw Exception('الكمية يجب أن تكون أكبر من الصفر.');
        }

        if (item.price < Decimal.zero) {
          throw Exception('السعر يجب أن يكون أكبر من أو يساوي الصفر.');
        }

        Decimal remainingToDeduct = item.quantity * item.unitFactor;

        final product = await (db.select(
          db.products,
        )..where((p) => p.id.equals(item.productId)))
            .getSingle();

        if (product.stock < remainingToDeduct) {
          throw Exception(
            'المخزون غير كافٍ للمنتج: ${product.name}. المتوفر: ${product.stock}',
          );
        }

        if (_costingService != null) {
          final batches = await _costingService!.getBatchesForSale(
            item.productId,
            remainingToDeduct,
          );

          Decimal totalDeducted = Decimal.zero;
          for (var batchData in batches) {
            if (batchData.remainingQuantity <= Decimal.zero) continue;

            await (db.update(
              db.productBatches,
            )..where((b) => b.id.equals(batchData.batch.id)))
                .write(
              ProductBatchesCompanion(
                quantity: Value(
                    batchData.batch.quantity - batchData.remainingQuantity),
              ),
            );

            await db.into(db.inventoryTransactions).insert(
                  InventoryTransactionsCompanion.insert(
                    productId: item.productId,
                    warehouseId: batchData.batch.warehouseId,
                    batchId: Value(batchData.batch.id),
                    quantity: -(batchData.remainingQuantity.toDouble()),
                    type: 'SALE',
                    referenceId: saleId,
                  ),
                );

            totalDeducted += batchData.remainingQuantity;
            saleCogs += batchData.remainingQuantity * batchData.costPerUnit;
          }

          await (db.update(
            db.products,
          )..where((p) => p.id.equals(item.productId)))
              .write(
            ProductsCompanion(stock: Value(product.stock - totalDeducted)),
          );
        } else {
          final batches = await (db.select(db.productBatches)
                ..where((b) => b.productId.equals(item.productId))
                ..where((b) => b.quantity.isBiggerThan(Variable(Decimal.zero.toString())))
                ..orderBy([
                  (b) => OrderingTerm(
                        expression: b.expiryDate.isNull(),
                        mode: OrderingMode.asc,
                      ),
                  (b) => OrderingTerm(
                        expression: b.expiryDate,
                        mode: OrderingMode.asc,
                      ),
                  (b) => OrderingTerm(
                        expression: b.createdAt,
                        mode: OrderingMode.asc,
                      ),
                ]))
              .get();

          Decimal totalDeducted = Decimal.zero;
          for (var batch in batches) {
            if (remainingToDeduct <= Decimal.zero) break;

            Decimal deductFromThisBatch = batch.quantity >= remainingToDeduct
                ? remainingToDeduct
                : batch.quantity;

            await (db.update(
              db.productBatches,
            )..where((b) => b.id.equals(batch.id)))
                .write(
              ProductBatchesCompanion(
                quantity: Value(batch.quantity - deductFromThisBatch),
              ),
            );

            await db.into(db.inventoryTransactions).insert(
                  InventoryTransactionsCompanion.insert(
                    productId: item.productId,
                    warehouseId: batch.warehouseId,
                    batchId: Value(batch.id),
                    quantity: -(deductFromThisBatch.toDouble()),
                    type: 'SALE',
                    referenceId: saleId,
                  ),
                );

            remainingToDeduct -= deductFromThisBatch;
            totalDeducted += deductFromThisBatch;
            saleCogs += deductFromThisBatch * batch.costPrice;
          }

          await (db.update(
            db.products,
          )..where((p) => p.id.equals(item.productId)))
              .write(
            ProductsCompanion(stock: Value(product.stock - totalDeducted)),
          );
        }
      }

      developer.log('Marking sale as posted: saleId=$saleId', name: 'invoice.lifecycle');
      await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(
        const SalesCompanion(status: Value(DocumentStatus.posted)),
      );

      if (sale.isCredit && sale.customerId != null) {
        final customer = await (db.select(
          db.customers,
        )..where((c) => c.id.equals(sale.customerId!)))
            .getSingle();

        await (db.update(
          db.customers,
        )..where((c) => c.id.equals(customer.id)))
            .write(
          CustomersCompanion(balance: Value(customer.balance + sale.total)),
        );
      }

      await _accountingService.postSale(sale, items, cogs: saleCogs, userId: userId);

      await _auditService.log(
        action: 'POST_SALE',
        targetEntity: 'Sales',
        entityId: saleId,
        userId: userId,
        details: 'Posted sale invoice $saleId',
      );

      eventBus.fire(
        SaleCreatedEvent(sale, items, cogs: saleCogs, userId: userId),
      );
    });
  }

  Future<void> postSaleReturn(String returnId, {String? userId}) async {
    await _checkAccountingPeriodOpen();

    final existingTransactions = await (db.select(db.inventoryTransactions)
          ..where((t) => t.referenceId.equals(returnId))
          ..where((t) => t.type.equals('RETURN')))
        .get();
    if (existingTransactions.isNotEmpty) {
      throw Exception('تم معالجة مردود المبيعات بالفعل');
    }

    await db.transaction(() async {
      final saleReturn = await (db.select(
        db.salesReturns,
      )..where((r) => r.id.equals(returnId)))
          .getSingle();

      final items = await (db.select(
        db.salesReturnItems,
      )..where((ri) => ri.salesReturnId.equals(returnId)))
          .get();

      final sale = await (db.select(
        db.sales,
      )..where((s) => s.id.equals(saleReturn.saleId)))
          .getSingle();

      for (var item in items) {
        Decimal returnQty = Decimal.parse(item.quantity.toString());
        final defaultWarehouse = await _configService.getDefaultWarehouseId();

        final product = await (db.select(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .getSingle();
        Decimal qtyInBaseUnit = Decimal.parse(returnQty.toString());

        final batchId = item.batchId;
        final batch = batchId != null
            ? await (db.select(db.productBatches)
                  ..where((b) => b.id.equals(batchId)))
                .getSingleOrNull()
            : null;

        if (batch != null) {
          await (db.update(db.productBatches)
                ..where((b) => b.id.equals(batch.id)))
              .write(
            ProductBatchesCompanion(
              quantity: Value(batch.quantity + qtyInBaseUnit),
            ),
          );
        } else {
          final existingBatches = await (db.select(db.productBatches)
                ..where((b) => b.productId.equals(item.productId))
                ..where((b) => b.quantity.isBiggerThan(Constant(Decimal.zero.toString())))
                ..orderBy([
                  (b) => OrderingTerm(
                        expression: b.expiryDate.isNull(),
                        mode: OrderingMode.asc,
                      ),
                  (b) => OrderingTerm(
                        expression: b.expiryDate,
                        mode: OrderingMode.asc,
                      ),
                ]))
              .get();

          if (existingBatches.isNotEmpty) {
            final targetBatch = existingBatches.first;
            await (db.update(db.productBatches)
                  ..where((b) => b.id.equals(targetBatch.id)))
                .write(
              ProductBatchesCompanion(
                quantity: Value(targetBatch.quantity + qtyInBaseUnit),
              ),
            );
          } else {
            final newBatchId = const Uuid().v4();
            await db.into(db.productBatches).insert(
                  ProductBatchesCompanion.insert(
                    id: Value(newBatchId),
                    productId: item.productId,
                    warehouseId: defaultWarehouse,
                    batchNumber: 'RETURN-${returnId.substring(0, 8)}',
                    expiryDate: const Value(null),
                    quantity: Value(qtyInBaseUnit),
                    initialQuantity: Value(qtyInBaseUnit),
                    costPrice: Value(product.buyPrice),
                  ),
                );
          }
        }

        await (db.update(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .write(
                ProductsCompanion(stock: Value(product.stock + qtyInBaseUnit)));

        final batchesAfterReturn = await (db.select(db.productBatches)
              ..where((b) => b.productId.equals(item.productId)))
            .get();
        Decimal batchSum = Decimal.zero;
        for (var b in batchesAfterReturn) {
          batchSum += b.quantity;
        }
        final Decimal newStock = product.stock + qtyInBaseUnit;
        if ((batchSum - newStock).abs() > Decimal.parse('0.01')) {
          developer.log(
            'WARNING: Stock/Batch mismatch after return. Product stock: $newStock, Batch sum: $batchSum',
            name: 'transaction_engine',
          );
        }

        await db.into(db.inventoryTransactions).insert(
              InventoryTransactionsCompanion.insert(
                productId: item.productId,
                warehouseId: batch?.warehouseId ?? defaultWarehouse,
                batchId: Value(batch?.id ?? ''),
                quantity: qtyInBaseUnit.toDouble(),
                type: 'RETURN',
                referenceId: returnId,
              ),
            );
      }

      if (sale.isCredit && sale.customerId != null) {
        final customer = await (db.select(db.customers)
              ..where((c) => c.id.equals(sale.customerId!)))
            .getSingle();
        await (db.update(db.customers)..where((c) => c.id.equals(customer.id)))
            .write(CustomersCompanion(
          balance: Value(customer.balance - Decimal.parse(saleReturn.amountReturned.toString())),
        ));
      }

      await _accountingService.postSaleReturn(saleReturn, items, userId ?? 'SYSTEM');

      eventBus.fire(SaleReturnCreatedEvent(saleReturn, items, userId: userId));
    });
  }

  Future<void> postPurchaseReturn(String returnId, {String? userId}) async {
    await _checkAccountingPeriodOpen();

    final existingTransactions = await (db.select(db.inventoryTransactions)
          ..where((t) => t.referenceId.equals(returnId))
          ..where((t) => t.type.equals('PURCHASE_RETURN')))
        .get();
    if (existingTransactions.isNotEmpty) {
      throw Exception('تم معالجة مردود المشتريات بالفعل');
    }

    await db.transaction(() async {
      final purchaseReturn = await (db.select(
        db.purchaseReturns,
      )..where((r) => r.id.equals(returnId)))
          .getSingle();

      final items = await (db.select(
        db.purchaseReturnItems,
      )..where((ri) => ri.purchaseReturnId.equals(returnId)))
          .get();

      final purchase = await (db.select(
        db.purchases,
      )..where((p) => p.id.equals(purchaseReturn.purchaseId)))
          .getSingle();

      for (var item in items) {
        Decimal remainingToDeduct = Decimal.parse(item.quantity.toString());

        final batches = await (db.select(db.productBatches)
              ..where((b) => b.productId.equals(item.productId))
              ..where((b) => b.quantity.isBiggerThan(Constant(Decimal.zero.toString())))
              ..orderBy([
                (b) => OrderingTerm(
                      expression: b.expiryDate.isNull(),
                      mode: OrderingMode.asc,
                    ),
                (b) => OrderingTerm(
                      expression: b.expiryDate,
                      mode: OrderingMode.asc,
                    ),
              ]))
            .get();

        for (var batch in batches) {
          if (remainingToDeduct <= Decimal.zero) break;

          Decimal deduct = batch.quantity >= remainingToDeduct
              ? remainingToDeduct
              : batch.quantity;

          await (db.update(
            db.productBatches,
          )..where((b) => b.id.equals(batch.id)))
              .write(
            ProductBatchesCompanion(quantity: Value(batch.quantity - deduct)),
          );

          await db.into(db.inventoryTransactions).insert(
                InventoryTransactionsCompanion.insert(
                  productId: item.productId,
                  warehouseId: batch.warehouseId,
                  batchId: Value(batch.id),
                  quantity: -(deduct.toDouble()),
                  type: 'PURCHASE_RETURN',
                  referenceId: returnId,
                ),
              );

          remainingToDeduct -= deduct;
        }

        final product = await (db.select(
          db.products,
        )..where((p) => p.id.equals(item.productId)))
            .getSingle();

        await (db.update(
          db.products,
        )..where((p) => p.id.equals(item.productId)))
            .write(
          ProductsCompanion(stock: Value(product.stock - Decimal.parse(item.quantity.toString()))),
        );
      }

      if (purchase.isCredit && purchase.supplierId != null) {
        final supplier = await (db.select(
          db.suppliers,
        )..where((s) => s.id.equals(purchase.supplierId!)))
            .getSingle();

        await (db.update(
          db.suppliers,
        )..where((s) => s.id.equals(supplier.id)))
            .write(
          SuppliersCompanion(
            balance: Value(supplier.balance - Decimal.parse(purchaseReturn.amountReturned.toString())),
          ),
        );
      }

      await _accountingService.postPurchaseReturn(purchaseReturn, items, userId ?? 'SYSTEM');

      eventBus.fire(
        PurchaseReturnCreatedEvent(purchaseReturn, items, userId: userId),
      );
    });
  }

  Future<void> postCustomerPayment({
    required String customerId,
    required Decimal amount,
    required String paymentMethod,
    String? note,
    String? userId,
    DateTime? paymentDate,
  }) async {
    await db.transaction(() async {
      final paymentId = const Uuid().v4();

      await db.into(db.customerPayments).insert(
            CustomerPaymentsCompanion.insert(
              id: Value(paymentId),
              customerId: customerId,
              amount: amount.toDouble(),
              paymentDate: Value(paymentDate ?? DateTime.now()),
              note: Value(note),
              syncStatus: const Value.absent(),
            ),
          );

      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals(customerId)))
          .getSingle();

      await (db.update(db.customers)..where((c) => c.id.equals(customerId)))
          .write(CustomersCompanion(balance: Value(customer.balance - amount)));

      await _accountingService.postCustomerPaymentEvent(
        CustomerPaymentEvent(
          customerId: customerId,
          amount: amount,
          paymentMethod: paymentMethod,
          note: note,
          paymentId: paymentId,
          userId: userId,
          paymentDate: paymentDate,
        ),
      );
    });
  }

  Future<void> postSupplierPayment({
    required String supplierId,
    required Decimal amount,
    required String paymentMethod,
    String? note,
    String? userId,
    DateTime? paymentDate,
  }) async {
    await db.transaction(() async {
      final paymentId = const Uuid().v4();

      await db.into(db.supplierPayments).insert(
            SupplierPaymentsCompanion.insert(
              id: Value(paymentId),
              supplierId: supplierId,
              amount: amount.toDouble(),
              paymentDate: Value(paymentDate ?? DateTime.now()),
              note: Value(note),
              syncStatus: const Value.absent(),
            ),
          );

      final supplier = await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(supplierId)))
          .getSingle();

      await (db.update(db.suppliers)..where((s) => s.id.equals(supplierId)))
          .write(SuppliersCompanion(balance: Value(supplier.balance - amount)));

      await _accountingService.postSupplierPaymentEvent(
        SupplierPaymentEvent(
          supplierId: supplierId,
          amount: amount,
          paymentMethod: paymentMethod,
          note: note,
          paymentId: paymentId,
          userId: userId,
          paymentDate: paymentDate,
        ),
      );
    });
  }

  Future<List<SaleWithBalance>> getOutstandingSales(String customerId) async {
    final sales = await (db.select(db.sales)
          ..where((s) => s.customerId.equals(customerId))
          ..where((s) => s.status.equals(DocumentStatus.posted.index))
          ..where((s) => s.isCredit.equals(true)))
        .get();

    final result = <SaleWithBalance>[];
    for (final sale in sales) {
      final payments = await (db.select(db.accountTransactions)
            ..where((t) => t.referenceId.equals(sale.id)))
          .get();

      Decimal totalPaid = Decimal.zero;
      for (final payment in payments) {
        totalPaid += (payment.credit - payment.debit);
      }

      final balance = sale.total - totalPaid;
      if (balance > Decimal.zero) {
        result.add(SaleWithBalance(sale: sale, balance: balance));
      }
    }
    return result;
  }

  Future<void> createCashReceipt({
    required Decimal amount,
    required String category,
    required String accountId,
    String? note,
    String? userId,
  }) async {
    final cashService = CashManagementService(db, _accountingService);
    await cashService.createCashReceipt(
      amount: amount.toDouble(),
      category: category,
      accountId: accountId,
      note: note,
      userId: userId,
    );
  }

  Future<void> createCashPayment({
    required Decimal amount,
    required String category,
    required String accountId,
    String? note,
    String? userId,
  }) async {
    final cashService = CashManagementService(db, _accountingService);
    await cashService.createCashPayment(
      amount: amount.toDouble(),
      category: category,
      accountId: accountId,
      note: note,
      userId: userId,
    );
  }
}

class SaleWithBalance {
  final Sale sale;
  final Decimal balance;
  SaleWithBalance({required this.sale, required this.balance});
}
