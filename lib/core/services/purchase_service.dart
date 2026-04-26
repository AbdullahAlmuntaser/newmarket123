import 'package:drift/drift.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:uuid/uuid.dart';

class PurchaseService {
  final AppDatabase db;
  final PostingEngine postingEngine;
  final InventoryCostingService inventoryCostingService;

  PurchaseService(this.db, this.postingEngine, this.inventoryCostingService);

  Future<Purchase> createPurchase({
    required String supplierId,
    required List<PurchaseItemsCompanion> items,
    required double total,
  }) async {
    final purchaseId = const Uuid().v4();
    final purchase = PurchasesCompanion.insert(
      id: Value(purchaseId),
      supplierId: Value(supplierId),
      date: Value(DateTime.now()),
      total: total,
      status: const Value('draft'),
    );

    await db.into(db.purchases).insert(purchase);

    for (var item in items) {
      await db
          .into(db.purchaseItems)
          .insert(item.copyWith(purchaseId: Value(purchaseId)));
    }

    return await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingle();
  }

  Future<void> postPurchase(String purchaseId) async {
    final purchase = await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingle();
    final items = await (db.select(
      db.purchaseItems,
    )..where((i) => i.purchaseId.equals(purchaseId))).get();

    for (var item in items) {
      await inventoryCostingService.returnToInventory(
        item.productId,
        item.quantity,
        item.unitPrice,
        InventoryTransactionType.purchase,
        transactionId: purchaseId,
      );
    }

    await postingEngine.post(
      type: TransactionType.purchase,
      referenceId: purchaseId,
      context: {
        'amount': purchase.total,
        'supplierId': purchase.supplierId,
        'description': 'Purchase Invoice #${purchase.id.substring(0, 8)}',
      },
    );
  }
}
