import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';
import 'accounting_service.dart';

class ReturnService {
  final AppDatabase db;

  ReturnService(this.db);

  Future<void> processSalesReturn({
    required String saleId,
    required List<ReturnItemData> items,
    String? reason,
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

        // 4. Return to Batch (simplification: return to the latest batch or a generic 'returned' batch)
        final latestBatch = await (db.select(db.productBatches)
              ..where((t) => t.productId.equals(item.productId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();

        if (latestBatch != null) {
          await (db.update(db.productBatches)..where((t) => t.id.equals(latestBatch.id))).write(
            ProductBatchesCompanion(quantity: Value(latestBatch.quantity + item.quantity)),
          );
        }
      }

      // 5. Accounting Entries
      final sale = await (db.select(db.sales)..where((t) => t.id.equals(saleId))).getSingle();
      final dao = db.accountingDao;
      final entryId = const Uuid().v4();

      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description: 'Sales Return for Sale #${saleId.substring(0, 8)}',
        date: Value(DateTime.now()),
        referenceType: const Value('SALES_RETURN'),
        referenceId: Value(returnId),
      );

      final salesReturnAcc = await dao.getAccountByCode(AccountingService.codeSalesRevenue); // Using revenue account for simplicity, or a specific Sales Return account if existed
      final creditAccCode = sale.isCredit ? AccountingService.codeAccountsReceivable : AccountingService.codeCash;
      final creditAcc = await dao.getAccountByCode(creditAccCode);

      if (salesReturnAcc != null && creditAcc != null) {
        final lines = [
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: salesReturnAcc.id,
            debit: Value(totalAmount), // Debit revenue to decrease it
            credit: const Value(0.0),
          ),
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: creditAcc.id,
            debit: const Value(0.0),
            credit: Value(totalAmount), // Credit cash/receivable to decrease it
          ),
        ];
        await dao.createEntry(entry, lines);
      }
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
