import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';
import 'accounting_service.dart';
import 'audit_service.dart';

class ReturnService {
  final AppDatabase db;
  late final AuditService _auditService;

  ReturnService(this.db) {
    _auditService = AuditService(db);
  }

  Future<void> processSalesReturn({
    required String saleId,
    required List<ReturnItemData> items,
    String? reason,
    String? userId,
  }) async {
    await db.transaction(() async {
      final returnId = const Uuid().v4();
      double totalAmount = 0;

      for (var item in items) {
        totalAmount += item.quantity * item.price;
      }

      // 1. Record Return
      await db.into(db.salesReturns).insert(
            SalesReturnsCompanion.insert(
              id: Value(returnId),
              saleId: saleId,
              amountReturned: totalAmount,
              reason: Value(reason),
            ),
          );

      double totalCogsToReverse = 0;

      for (var item in items) {
        // 2. Record Return Items
        await db.into(db.salesReturnItems).insert(
              SalesReturnItemsCompanion.insert(
                id: Value(const Uuid().v4()),
                salesReturnId: returnId,
                productId: item.productId,
                quantity: item.quantity,
                price: item.price,
              ),
            );

        // 3. Update Stock
        final product = await (db.select(db.products)
              ..where((t) => t.id.equals(item.productId)))
            .getSingle();
        await (db.update(db.products)..where((t) => t.id.equals(item.productId))).write(
          ProductsCompanion(stock: Value(product.stock + item.quantity)),
        );

        // 4. Return to Batch (FIFO logic reverse)
        // Find latest batch affected or add to newest batch
        final latestBatch = await (db.select(db.productBatches)
              ..where((t) => t.productId.equals(item.productId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();

        if (latestBatch != null) {
          await (db.update(db.productBatches)..where((t) => t.id.equals(latestBatch.id))).write(
            ProductBatchesCompanion(quantity: Value(latestBatch.quantity + item.quantity)),
          );
          totalCogsToReverse += item.quantity * latestBatch.costPrice;
        }
      }

      // 5. Accounting Entries
      final sale = await (db.select(db.sales)..where((t) => t.id.equals(saleId))).getSingle();
      final dao = db.accountingDao;
      
      // A. Revenue Reversal
      final entryId = const Uuid().v4();
      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description: 'Sales Return for Sale #${saleId.substring(0, 8)}',
        date: Value(DateTime.now()),
        referenceType: const Value('SALES_RETURN'),
        referenceId: Value(returnId),
      );

      final salesRevenueAcc = await dao.getAccountByCode(AccountingService.codeSalesRevenue);
      final creditAccCode = sale.isCredit ? AccountingService.codeAccountsReceivable : AccountingService.codeCash;
      final creditAcc = await dao.getAccountByCode(creditAccCode);

      if (salesRevenueAcc != null && creditAcc != null) {
        final lines = [
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: salesRevenueAcc.id,
            debit: Value(totalAmount),
            credit: const Value(0.0),
          ),
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: creditAcc.id,
            debit: const Value(0.0),
            credit: Value(totalAmount),
          ),
        ];
        await dao.createEntry(entry, lines);
      }

      // B. COGS Reversal (if value exists)
      if (totalCogsToReverse > 0) {
        final cogsEntryId = const Uuid().v4();
        final cogsAcc = await dao.getAccountByCode(AccountingService.codeCOGS);
        final inventoryAcc = await dao.getAccountByCode(AccountingService.codeInventory);

        if (cogsAcc != null && inventoryAcc != null) {
          final cogsEntry = GLEntriesCompanion.insert(
            id: Value(cogsEntryId),
            description: 'COGS Reversal for Sales Return #$returnId',
            date: Value(DateTime.now()),
            referenceType: const Value('SALES_RETURN_COGS'),
            referenceId: Value(returnId),
          );

          final cogsLines = [
            GLLinesCompanion.insert(
              entryId: cogsEntryId,
              accountId: inventoryAcc.id,
              debit: Value(totalCogsToReverse),
              credit: const Value(0.0),
            ),
            GLLinesCompanion.insert(
              entryId: cogsEntryId,
              accountId: cogsAcc.id,
              debit: const Value(0.0),
              credit: Value(totalCogsToReverse),
            ),
          ];
          await dao.createEntry(cogsEntry, cogsLines);
        }
      }

      // 6. Audit
      await _auditService.log(
        action: 'SALES_RETURN',
        targetEntity: 'SalesReturns',
        entityId: returnId,
        userId: userId,
        details: 'Processed sales return for sale $saleId. Total: $totalAmount',
      );
    });
  }

  Future<void> processPurchaseReturn({
    required String purchaseId,
    required List<ReturnItemData> items,
    String? reason,
    String? userId,
  }) async {
    await db.transaction(() async {
      final returnId = const Uuid().v4();
      double totalAmount = 0;

      for (var item in items) {
        totalAmount += item.quantity * item.price;
      }

      // 1. Record Return
      await db.into(db.purchaseReturns).insert(
            PurchaseReturnsCompanion.insert(
              id: Value(returnId),
              purchaseId: purchaseId,
              amountReturned: totalAmount,
              reason: Value(reason),
            ),
          );

      for (var item in items) {
        // 2. Record Return Items
        await db.into(db.purchaseReturnItems).insert(
              PurchaseReturnItemsCompanion.insert(
                id: Value(const Uuid().v4()),
                purchaseReturnId: returnId,
                productId: item.productId,
                quantity: item.quantity,
                price: item.price,
              ),
            );

        // 3. Update Stock
        final product = await (db.select(db.products)
              ..where((t) => t.id.equals(item.productId)))
            .getSingle();
        await (db.update(db.products)..where((t) => t.id.equals(item.productId))).write(
          ProductsCompanion(stock: Value(product.stock - item.quantity)),
        );

        // 4. Update Batches (Decrease newest batches first)
        double remainingToDeduct = item.quantity;
        final batches = await (db.select(db.productBatches)
              ..where((t) => t.productId.equals(item.productId) & t.quantity.isBiggerThanValue(0))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

        for (var batch in batches) {
          if (remainingToDeduct <= 0) break;
          double deduct = batch.quantity >= remainingToDeduct ? remainingToDeduct : batch.quantity;
          await (db.update(db.productBatches)..where((t) => t.id.equals(batch.id))).write(
            ProductBatchesCompanion(quantity: Value(batch.quantity - deduct)),
          );
          remainingToDeduct -= deduct;
        }
      }

      // 5. Accounting Entries
      final purchase = await (db.select(db.purchases)..where((t) => t.id.equals(purchaseId))).getSingle();
      final dao = db.accountingDao;
      final entryId = const Uuid().v4();

      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description: 'Purchase Return for Purchase #${purchaseId.substring(0, 8)}',
        date: Value(DateTime.now()),
        referenceType: const Value('PURCHASE_RETURN'),
        referenceId: Value(returnId),
      );

      final inventoryAcc = await dao.getAccountByCode(AccountingService.codeInventory);
      final debtAccCode = purchase.isCredit ? AccountingService.codeAccountsPayable : AccountingService.codeCash;
      final debtAcc = await dao.getAccountByCode(debtAccCode);

      if (inventoryAcc != null && debtAcc != null) {
        final lines = [
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: debtAcc.id,
            debit: Value(totalAmount), // Debit payable/cash to decrease it
            credit: const Value(0.0),
          ),
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: inventoryAcc.id,
            debit: const Value(0.0),
            credit: Value(totalAmount), // Credit inventory to decrease it
          ),
        ];
        await dao.createEntry(entry, lines);
      }

      // 6. Audit
      await _auditService.log(
        action: 'PURCHASE_RETURN',
        targetEntity: 'PurchaseReturns',
        entityId: returnId,
        userId: userId,
        details: 'Processed purchase return for purchase $purchaseId. Total: $totalAmount',
      );
    });
  }
}

class ReturnItemData {
  final String productId;
  final double quantity;
  final double price;

  ReturnItemData({
    required this.productId,
    required this.quantity,
    required this.price,
  });
}
