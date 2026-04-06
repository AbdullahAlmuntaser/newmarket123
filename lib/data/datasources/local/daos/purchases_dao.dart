import 'dart:convert';
import 'package:drift/drift.dart';
import '../app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';

part 'purchases_dao.g.dart';

@DriftAccessor(tables: [Purchases, PurchaseItems, Products, Suppliers, SyncQueue, AuditLogs, ProductBatches])
class PurchasesDao extends DatabaseAccessor<AppDatabase> with _$PurchasesDaoMixin {
  PurchasesDao(super.db);

  Stream<List<Purchase>> watchAllPurchases() => select(purchases).watch();

  Stream<List<PurchaseItem>> watchPurchaseItems(String purchaseId) {
    return (select(purchaseItems)..where((pi) => pi.purchaseId.equals(purchaseId))).watch();
  }

  Future<Purchase?> getPurchaseById(String id) {
    return (select(purchases)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<void> createPurchase({
    required PurchasesCompanion purchaseCompanion,
    required List<PurchaseItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    return transaction(() async {
      // 1. Insert Purchase
      final purchaseId = await into(purchases).insert(purchaseCompanion);

      // 2. Process Items
      for (var item in itemsCompanions) {
        await into(purchaseItems).insert(item.copyWith(purchaseId: Value(purchaseId as String)));

        // Update Stock and Buy Price
        final product = await (select(products)..where((p) => p.id.equals(item.productId.value))).getSingle();
        
        // Update product buy price and stock
        await (update(products)..where((p) => p.id.equals(item.productId.value))).write(
          ProductsCompanion(
            stock: Value(product.stock + item.quantity.value),
            buyPrice: Value(item.price.value), // Update last buy price
          ),
        );

        // Handle Batches if warehouseId is provided
        if (purchaseCompanion.warehouseId.value != null) {
           await into(productBatches).insert(ProductBatchesCompanion.insert(
            productId: item.productId.value,
            warehouseId: purchaseCompanion.warehouseId.value!,
            batchNumber: 'PUR-${purchaseId.toString().substring(0, 8)}',
            quantity: Value(item.quantity.value),
            initialQuantity: Value(item.quantity.value),
            costPrice: Value(item.price.value),
          ));
        }      }

      // 3. Update Supplier Balance if Credit
      if (purchaseCompanion.isCredit.value == true && purchaseCompanion.supplierId.value != null) {
        final supplier = await (select(suppliers)..where((s) => s.id.equals(purchaseCompanion.supplierId.value!))).getSingle();
        await (update(suppliers)..where((s) => s.id.equals(purchaseCompanion.supplierId.value!))).write(
          SuppliersCompanion(balance: Value(supplier.balance + purchaseCompanion.total.value)),
        );
      }

      // 4. Sync Queue
      final payload = {
        'id': purchaseId,
        'total': purchaseCompanion.total.value,
        'items': itemsCompanions.map((i) => {
          'productId': i.productId.value,
          'qty': i.quantity.value,
          'price': i.price.value,
        }).toList(),
      };
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityTable: 'purchases',
        entityId: purchaseId as String,
        operation: 'create',
        payload: jsonEncode(payload),
      ));

      // 5. Accounting
      final purchaseObj = await (select(purchases)..where((p) => p.id.equals(purchaseId as String))).getSingle();
      final accounting = AccountingService(db);
      await accounting.seedDefaultAccounts();
      
      // Get inserted items
      final insertedItems = await (select(purchaseItems)..where((pi) => pi.purchaseId.equals(purchaseId as String))).get();
      await accounting.postPurchase(purchaseObj, insertedItems);

      // 6. Audit Log
      await into(auditLogs).insert(AuditLogsCompanion.insert(
        userId: Value(userId),
        action: 'CREATE',
        targetEntity: 'PURCHASES',
        entityId: purchaseId as String,
        details: Value('Created purchase: $purchaseId, Total: ${purchaseCompanion.total.value}'),
      ));
    });
  }
}
