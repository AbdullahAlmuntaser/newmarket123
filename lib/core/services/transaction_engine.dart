import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/core/services/cash_management_service.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/budget_service.dart';
import 'package:supermarket/core/services/approval_workflow_service.dart';
import 'package:uuid/uuid.dart';

/// Single source of truth for all business transactions.
/// Every operation is atomic - if any step fails, the entire transaction rolls back.
class TransactionEngine {
  final AppDatabase db;
  final EventBusService eventBus;
  final AuditService _auditService;
  final AppConfigService _configService;
  final PostingEngine _postingEngine;
  final PackagingEngine packagingEngine;
  BudgetService? _budgetService;
  ApprovalWorkflowService? _approvalService;
  InventoryCostingService? _costingService;

  TransactionEngine(
    this.db,
    this.eventBus,
    this._postingEngine,
    this.packagingEngine,
  )   : _auditService = AuditService(db),
        _configService = AppConfigService(db);

  void setCostingService(InventoryCostingService costingService) {
    _costingService = costingService;
  }

  /// Wire budget validation service
  void setBudgetService(BudgetService budgetService) {
    _budgetService = budgetService;
  }

  /// Wire approval workflow service
  void setApprovalService(ApprovalWorkflowService approvalService) {
    _approvalService = approvalService;
  }

  Future<void> _checkAccountingPeriodOpen() async {
    final now = DateTime.now();
    final openPeriod = await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..where((p) => p.startDate.isSmallerOrEqual(Variable(now)))
          ..where((p) => p.endDate.isBiggerOrEqual(Variable(now))))
        .get()
        .then((rows) => rows.isEmpty ? null : rows.first);
    if (openPeriod == null) {
      throw Exception(
          'لا توجد فترة محاسبية مفتوحة حالياً. يرجى فتح فترة محاسبية جديدة.');
    }
  }

  /// ==================== POST PURCHASE ====================
  /// Creates: Purchase + Stock + Batches + GL Entry + Supplier Balance
  Future<void> postPurchase(String purchaseId, {String? userId}) async {
    if (purchaseId.isEmpty) {
      throw Exception('معرف الفاتورة غير صالح.');
    }

    await _checkAccountingPeriodOpen();

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

      // Check if purchase requires approval (amount > 10,000)
      if (_approvalService != null && purchase.total > Decimal.fromInt(10000)) {
        final existingRequest = await _approvalService!.getRequestByReferenceId(purchaseId);
        if (existingRequest == null) {
          // Submit for approval instead of posting directly
          await _approvalService!.submitRequest(
            type: 'PURCHASE',
            title: 'فاتورة مشتريات #${purchaseId.substring(0, 8)}',
            amount: purchase.total.toDouble(),
            requestedBy: userId ?? 'system',
            referenceId: purchaseId,
          );
          // Update purchase status to indicate pending approval
          await (db.update(db.purchases)..where((p) => p.id.equals(purchaseId)))
              .write(const PurchasesCompanion(status: Value(DocumentStatus.draft)));
          return; // Exit - don't post yet
        } else if (!existingRequest.isApproved) {
          throw Exception('هذه الفاتورة بانتظار الموافقة. لا يمكن الترحيل حتى تتم الموافقة عليها.');
        }
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

      // Process each item: update stock, create batches, allocate landed costs
      for (var item in items) {
        Decimal itemValue = item.quantity * item.price;
        Decimal proportion = subtotal > Decimal.zero
            ? (itemValue / subtotal).toDecimal()
            : Decimal.zero;
        Decimal allocatedLandedCost = purchase.landedCosts * proportion;
        Decimal landedCostPerUnit = item.quantity > Decimal.zero
            ? (allocatedLandedCost / item.quantity).toDecimal()
            : Decimal.zero;
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
                quantity: Value(qtyInBaseUnit),
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

      // Update purchase status
      await (db.update(db.purchases)..where((p) => p.id.equals(purchaseId)))
          .write(
              const PurchasesCompanion(status: Value(DocumentStatus.received)));

      // Update supplier balance for credit purchases
      if (purchase.isCredit && purchase.supplierId != null) {
        final supplier = await (db.select(
          db.suppliers,
        )..where((s) => s.id.equals(purchase.supplierId!)))
            .getSingle();
        await (db.update(
          db.suppliers,
        )..where((s) => s.id.equals(supplier.id)))
            .write(
          SuppliersCompanion(balance: Value(supplier.balance + purchase.total)),
        );
      }

      // Single accounting entry through PostingEngine
      await _postingEngine.post(
        type: TransactionType.purchase,
        referenceId: purchaseId,
        context: {
          'amount': purchase.total,
          'tax': purchase.tax,
          'paymentMethod': purchase.isCredit ? 'credit' : 'cash',
          'description': 'إثبات فاتورة مشتريات #${purchaseId.substring(0, 8)}',
          'supplierId': purchase.supplierId,
          'branchId': purchase.branchId,
          'currencyId': purchase.currencyId,
          'exchangeRate': purchase.exchangeRate,
          'date': purchase.date,
        },
      );

      await _auditService.log(
        action: 'POST_PURCHASE',
        targetEntity: 'Purchases',
        entityId: purchaseId,
        userId: userId,
        details: 'Posted purchase invoice $purchaseId',
      );

      eventBus.fire(PurchasePostedEvent(purchase, items, userId: userId));
    });
  }

  /// ==================== POST SALE ====================
  /// Creates: Sale Status + Stock Deduction + Batch Deduction + GL Entry + Customer Balance
  Future<void> postSale(String saleId, {String? userId}) async {
    await _checkAccountingPeriodOpen();

    final saleCheck = await (db.select(db.sales)
          ..where((s) => s.id.equals(saleId)))
        .getSingleOrNull();
    if (saleCheck == null) throw Exception('الفاتورة غير موجودة.');
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

        // Auto-break packaging if necessary
        await packagingEngine.autoBreakIfNecessary(
          productId: item.productId,
          warehouseId: sale.warehouseId ?? '',
          requiredQtyInBase: remainingToDeduct,
        );

        // Deduct from batches using costing service or FIFO
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
                    quantity: Value(-(batchData.remainingQuantity)),
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
          // FIFO fallback
          final batches = await (db.select(db.productBatches)
                ..where((b) => b.productId.equals(item.productId))
                ..where((b) =>
                    b.quantity.isBiggerThan(Variable(Decimal.zero.toString())))
                ..orderBy([
                  (b) => OrderingTerm(
                      expression: b.expiryDate.isNull(),
                      mode: OrderingMode.asc),
                  (b) => OrderingTerm(
                      expression: b.expiryDate, mode: OrderingMode.asc),
                  (b) => OrderingTerm(
                      expression: b.createdAt, mode: OrderingMode.asc),
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
                  quantity: Value(batch.quantity - deductFromThisBatch)),
            );
            await db.into(db.inventoryTransactions).insert(
                  InventoryTransactionsCompanion.insert(
                    productId: item.productId,
                    warehouseId: batch.warehouseId,
                    batchId: Value(batch.id),
                    quantity: Value(-(deductFromThisBatch)),
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

      // Mark sale as posted
      await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(
        const SalesCompanion(status: Value(DocumentStatus.posted)),
      );

      // Update customer balance for credit sales
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

      // Single accounting entry through PostingEngine (revenue + tax)
      await _postingEngine.post(
        type: TransactionType.sale,
        referenceId: saleId,
        context: {
          'amount': sale.total,
          'tax': sale.tax,
          'cogs': saleCogs,
          'paymentMethod': sale.isCredit ? 'credit' : 'cash',
          'description': 'إثبات فاتورة مبيعات #${saleId.substring(0, 8)}',
          'customerId': sale.customerId,
          'branchId': sale.branchId,
          'currencyId': sale.currencyId,
          'exchangeRate': sale.exchangeRate,
          'date': sale.createdAt,
        },
      );

      await _auditService.log(
        action: 'POST_SALE',
        targetEntity: 'Sales',
        entityId: saleId,
        userId: userId,
        details: 'Posted sale invoice $saleId',
      );

      eventBus
          .fire(SaleCreatedEvent(sale, items, cogs: saleCogs, userId: userId));
    });
  }

  /// ==================== POST SALE RETURN ====================
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
        Decimal returnQty = item.quantity;
        final defaultWarehouse = await _configService.getDefaultWarehouseId();
        final product = await (db.select(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .getSingle();

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
                quantity: Value(batch.quantity + returnQty)),
          );
        } else {
          final existingBatches = await (db.select(db.productBatches)
                ..where((b) => b.productId.equals(item.productId))
                ..where((b) =>
                    b.quantity.isBiggerThan(Constant(Decimal.zero.toString())))
                ..orderBy([
                  (b) => OrderingTerm(
                      expression: b.expiryDate.isNull(),
                      mode: OrderingMode.asc),
                  (b) => OrderingTerm(
                      expression: b.expiryDate, mode: OrderingMode.asc),
                ]))
              .get();
          if (existingBatches.isNotEmpty) {
            final targetBatch = existingBatches.first;
            await (db.update(db.productBatches)
                  ..where((b) => b.id.equals(targetBatch.id)))
                .write(
              ProductBatchesCompanion(
                  quantity: Value(targetBatch.quantity + returnQty)),
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
                    quantity: Value(returnQty),
                    initialQuantity: Value(returnQty),
                    costPrice: Value(product.buyPrice),
                  ),
                );
          }
        }

        await (db.update(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .write(ProductsCompanion(stock: Value(product.stock + returnQty)));

        // Auto-reconcile batch vs product stock
        final batchesAfterReturn = await (db.select(db.productBatches)
              ..where((b) => b.productId.equals(item.productId)))
            .get();
        Decimal batchSum = Decimal.zero;
        for (var b in batchesAfterReturn) {
          batchSum += b.quantity;
        }
        final Decimal newStock = product.stock + returnQty;
        if ((batchSum - newStock).abs() > Decimal.parse('0.01')) {
          final mismatch = newStock - batchSum;
          if (batchesAfterReturn.isNotEmpty) {
            final targetBatch = batchesAfterReturn
                .reduce((a, b) => a.quantity > b.quantity ? a : b);
            await (db.update(db.productBatches)
                  ..where((b) => b.id.equals(targetBatch.id)))
                .write(ProductBatchesCompanion(
                    quantity: Value(targetBatch.quantity + mismatch)));
          }
        }

        await db.into(db.inventoryTransactions).insert(
              InventoryTransactionsCompanion.insert(
                productId: item.productId,
                warehouseId: batch?.warehouseId ?? defaultWarehouse,
                batchId: Value(batch?.id ?? ''),
                quantity: Value(returnQty),
                type: 'RETURN',
                referenceId: returnId,
              ),
            );
      }

      // Reverse customer balance for credit sales
      if (sale.isCredit && sale.customerId != null) {
        final customer = await (db.select(db.customers)
              ..where((c) => c.id.equals(sale.customerId!)))
            .getSingle();
        await (db.update(db.customers)..where((c) => c.id.equals(customer.id)))
            .write(CustomersCompanion(
          balance: Value(customer.balance - saleReturn.amountReturned),
        ));
      }

      // Single accounting through PostingEngine
      await _postingEngine.post(
        type: TransactionType.saleReturn,
        referenceId: returnId,
        context: {
          'amount': saleReturn.amountReturned,
          'originalSaleId': saleReturn.saleId,
          'paymentMethod': sale.isCredit ? 'credit' : 'cash',
          'description': 'مردود مبيعات #${returnId.substring(0, 8)}',
          'branchId': sale.branchId,
          'date': saleReturn.createdAt,
        },
      );

      eventBus.fire(SaleReturnCreatedEvent(saleReturn, items, userId: userId));
    });
  }

  /// ==================== POST PURCHASE RETURN ====================
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
        Decimal remainingToDeduct = item.quantity;
        final batches = await (db.select(db.productBatches)
              ..where((b) => b.productId.equals(item.productId))
              ..where((b) =>
                  b.quantity.isBiggerThan(Constant(Decimal.zero.toString())))
              ..orderBy([
                (b) => OrderingTerm(
                    expression: b.expiryDate.isNull(), mode: OrderingMode.asc),
                (b) => OrderingTerm(
                    expression: b.expiryDate, mode: OrderingMode.asc),
              ]))
            .get();

        for (var batch in batches) {
          if (remainingToDeduct <= Decimal.zero) break;
          Decimal deduct = batch.quantity >= remainingToDeduct
              ? remainingToDeduct
              : batch.quantity;
          await (db.update(db.productBatches)
                ..where((b) => b.id.equals(batch.id)))
              .write(ProductBatchesCompanion(
                  quantity: Value(batch.quantity - deduct)));
          await db.into(db.inventoryTransactions).insert(
                InventoryTransactionsCompanion.insert(
                  productId: item.productId,
                  warehouseId: batch.warehouseId,
                  batchId: Value(batch.id),
                  quantity: Value(-(deduct)),
                  type: 'PURCHASE_RETURN',
                  referenceId: returnId,
                ),
              );
          remainingToDeduct -= deduct;
        }

        final product = await (db.select(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .getSingle();
        await (db.update(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .write(
                ProductsCompanion(stock: Value(product.stock - item.quantity)));
      }

      // Reverse supplier balance
      if (purchase.isCredit && purchase.supplierId != null) {
        final supplier = await (db.select(db.suppliers)
              ..where((s) => s.id.equals(purchase.supplierId!)))
            .getSingle();
        await (db.update(db.suppliers)..where((s) => s.id.equals(supplier.id)))
            .write(SuppliersCompanion(
          balance: Value(supplier.balance - purchaseReturn.amountReturned),
        ));
      }

      // Single accounting through PostingEngine
      await _postingEngine.post(
        type: TransactionType.purchaseReturn,
        referenceId: returnId,
        context: {
          'amount': purchaseReturn.amountReturned,
          'originalPurchaseId': purchaseReturn.purchaseId,
          'paymentMethod': purchase.isCredit ? 'credit' : 'cash',
          'description': 'مردود مشتريات #${returnId.substring(0, 8)}',
          'branchId': purchase.branchId,
          'date': purchaseReturn.createdAt,
        },
      );

      eventBus.fire(
          PurchaseReturnCreatedEvent(purchaseReturn, items, userId: userId));
    });
  }

  /// ==================== CUSTOMER PAYMENT ====================
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
              amount: amount,
              paymentDate: Value(paymentDate ?? DateTime.now()),
              note: Value(note),
              syncStatus: const Value.absent(),
            ),
          );

      final customer = await (db.select(db.customers)
            ..where((c) => c.id.equals(customerId)))
          .getSingle();
      await (db.update(db.customers)..where((c) => c.id.equals(customerId)))
          .write(CustomersCompanion(balance: Value(customer.balance - amount)));

      // GL entry through PostingEngine
      await _postingEngine.post(
        type: TransactionType.customerPayment,
        referenceId: paymentId,
        context: {
          'amount': amount,
          'customerId': customerId,
          'paymentMethod': paymentMethod,
          'note': note,
          'description': 'سند قبض من ${customer.name}',
          'date': paymentDate ?? DateTime.now(),
        },
      );
    });
  }

  /// ==================== SUPPLIER PAYMENT ====================
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
              amount: amount,
              paymentDate: Value(paymentDate ?? DateTime.now()),
              note: Value(note),
              syncStatus: const Value.absent(),
            ),
          );

      final supplier = await (db.select(db.suppliers)
            ..where((s) => s.id.equals(supplierId)))
          .getSingle();
      await (db.update(db.suppliers)..where((s) => s.id.equals(supplierId)))
          .write(SuppliersCompanion(balance: Value(supplier.balance - amount)));

      await _postingEngine.post(
        type: TransactionType.supplierPayment,
        referenceId: paymentId,
        context: {
          'amount': amount,
          'supplierId': supplierId,
          'paymentMethod': paymentMethod,
          'note': note,
          'description': 'سند صرف إلى ${supplier.name}',
          'date': paymentDate ?? DateTime.now(),
        },
      );
    });
  }

  /// ==================== CUSTOMER PAYMENT WITH ALLOCATIONS ====================
  Future<void> postCustomerPaymentWithAllocations({
    required String customerId,
    required Decimal amount,
    required String paymentMethod,
    String? note,
    String? userId,
    DateTime? paymentDate,
    required List<({String saleId, Decimal amount})> allocations,
  }) async {
    await db.transaction(() async {
      final paymentId = const Uuid().v4();
      await db.into(db.customerPayments).insert(
            CustomerPaymentsCompanion.insert(
              id: Value(paymentId),
              customerId: customerId,
              amount: amount,
              paymentDate: Value(paymentDate ?? DateTime.now()),
              note: Value(note),
              syncStatus: const Value.absent(),
            ),
          );

      for (final alloc in allocations) {
        await db.into(db.customerPaymentLinks).insert(
              CustomerPaymentLinksCompanion.insert(
                paymentId: paymentId,
                saleId: alloc.saleId,
                amount: Value(alloc.amount),
              ),
            );
      }

      final customer = await (db.select(db.customers)
            ..where((c) => c.id.equals(customerId)))
          .getSingle();
      await (db.update(db.customers)..where((c) => c.id.equals(customerId)))
          .write(CustomersCompanion(balance: Value(customer.balance - amount)));

      await _postingEngine.post(
        type: TransactionType.customerPayment,
        referenceId: paymentId,
        context: {
          'amount': amount,
          'customerId': customerId,
          'paymentMethod': paymentMethod,
          'note': note,
          'description': 'سند قبض ${customer.name} (توزيعات)',
          'date': paymentDate ?? DateTime.now(),
        },
      );
    });
  }

  /// ==================== SUPPLIER PAYMENT WITH ALLOCATIONS ====================
  Future<void> postSupplierPaymentWithAllocations({
    required String supplierId,
    required Decimal amount,
    required String paymentMethod,
    String? note,
    String? userId,
    DateTime? paymentDate,
    required List<({String purchaseId, Decimal amount})> allocations,
  }) async {
    await db.transaction(() async {
      final paymentId = const Uuid().v4();
      await db.into(db.supplierPayments).insert(
            SupplierPaymentsCompanion.insert(
              id: Value(paymentId),
              supplierId: supplierId,
              amount: amount,
              paymentDate: Value(paymentDate ?? DateTime.now()),
              note: Value(note),
              syncStatus: const Value.absent(),
            ),
          );

      for (final alloc in allocations) {
        await db.into(db.purchasePaymentLinks).insert(
              PurchasePaymentLinksCompanion.insert(
                paymentId: paymentId,
                purchaseId: alloc.purchaseId,
                amount: alloc.amount,
              ),
            );
      }

      final supplier = await (db.select(db.suppliers)
            ..where((s) => s.id.equals(supplierId)))
          .getSingle();
      await (db.update(db.suppliers)..where((s) => s.id.equals(supplierId)))
          .write(SuppliersCompanion(balance: Value(supplier.balance - amount)));

      await _postingEngine.post(
        type: TransactionType.supplierPayment,
        referenceId: paymentId,
        context: {
          'amount': amount,
          'supplierId': supplierId,
          'paymentMethod': paymentMethod,
          'note': note,
          'description': 'سند صرف ${supplier.name} (توزيعات)',
          'date': paymentDate ?? DateTime.now(),
        },
      );
    });
  }

  /// ==================== CASH TRANSACTIONS ====================
  Future<void> createCashReceipt({
    required Decimal amount,
    required String category,
    required String accountId,
    String? note,
    String? userId,
  }) async {
    final cashService = CashManagementService(db, _postingEngine);
    await cashService.createCashReceipt(
      amount: amount,
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
    String? costCenterId,
  }) async {
    // Validate against budget if cost center is provided
    if (costCenterId != null && _budgetService != null) {
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await _budgetService!.validateExpenseAgainstBudget(
        costCenterId: costCenterId,
        expenseAmount: amount,
        period: period,
      );
    }

    final cashService = CashManagementService(db, _postingEngine);
    await cashService.createCashPayment(
      amount: amount,
      category: category,
      accountId: accountId,
      note: note,
      userId: userId,
    );

    // Update budget actual amount if cost center is provided
    if (costCenterId != null && _budgetService != null) {
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await _budgetService!.updateActualBudget(
        costCenterId: costCenterId,
        expenseAmount: amount,
        period: period,
      );
    }
  }

  /// ==================== OUTSTANDING BALANCES ====================
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

  Future<List<PurchaseWithBalance>> getOutstandingPurchases(
      String supplierId) async {
    final purchases = await (db.select(db.purchases)
          ..where((p) => p.supplierId.equals(supplierId))
          ..where((p) => p.status.equals(DocumentStatus.posted.index))
          ..where((p) => p.isCredit.equals(true)))
        .get();

    final result = <PurchaseWithBalance>[];
    for (final purchase in purchases) {
      final payments = await (db.select(db.accountTransactions)
            ..where((t) => t.referenceId.equals(purchase.id)))
          .get();
      Decimal totalPaid = Decimal.zero;
      for (final payment in payments) {
        totalPaid += (payment.debit - payment.credit);
      }
      final balance = purchase.total - totalPaid;
      if (balance > Decimal.zero) {
        result.add(PurchaseWithBalance(purchase: purchase, balance: balance));
      }
    }
    return result;
  }
}

class SaleWithBalance {
  final Sale sale;
  final Decimal balance;
  SaleWithBalance({required this.sale, required this.balance});
}

class PurchaseWithBalance {
  final Purchase purchase;
  final Decimal balance;
  PurchaseWithBalance({required this.purchase, required this.balance});
}
