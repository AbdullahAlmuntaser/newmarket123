import 'package:drift/drift.dart';
import '../app_database.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:uuid/uuid.dart';

part 'purchases_dao.g.dart';

@DriftAccessor(
  tables: [
    Purchases,
    PurchaseItems,
    Products,
    Suppliers,
    SyncQueue,
    AuditLogs,
    ProductBatches,
    PurchaseReturns,
    PurchaseReturnItems,
  ],
)
class PurchasesDao extends DatabaseAccessor<AppDatabase>
    with _$PurchasesDaoMixin {
  PurchasesDao(super.db);

  EventBusService get _eventBus => sl<EventBusService>();

  Stream<List<Purchase>> watchAllPurchases() => select(purchases).watch();

  Stream<List<PurchaseItem>> watchPurchaseItems(String purchaseId) {
    return (select(
      purchaseItems,
    )..where((pi) => pi.purchaseId.equals(purchaseId))).watch();
  }

  Future<Purchase?> getPurchaseById(String id) {
    return (select(purchases)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<List<PurchaseReturn>> watchAllPurchaseReturns() {
    return (select(purchaseReturns)..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Stream<List<PurchaseReturnItem>> watchPurchaseReturnItems(String returnId) {
    return (select(
      purchaseReturnItems,
    )..where((pi) => pi.purchaseReturnId.equals(returnId))).watch();
  }

  Future<void> createPurchase({
    required PurchasesCompanion purchaseCompanion,
    required List<PurchaseItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    if (itemsCompanions.isEmpty) {
      throw Exception('لا يمكن إنشاء فاتورة مشتريات بدون أصناف.');
    }

    return transaction(() async {
      // Recalculate Totals
      double calculatedSubtotal = 0.0;
      for (var item in itemsCompanions) {
        calculatedSubtotal += item.quantity.value * item.price.value;
      }
      final tax = purchaseCompanion.tax.value;
      final landedCosts = purchaseCompanion.landedCosts.value;
      final calculatedTotal = calculatedSubtotal + tax + landedCosts;

      final finalPurchaseCompanion = purchaseCompanion.copyWith(
        total: Value(calculatedTotal),
      );

      // 1. Insert Purchase
      await into(purchases).insert(finalPurchaseCompanion);

      // 2. Process Items
      for (var item in itemsCompanions) {
        // Calculate allocated landed cost for this item (by value proportion)
        double itemValue = item.quantity.value * item.price.value;
        double proportion = calculatedSubtotal > 0 ? itemValue / calculatedSubtotal : 0;
        double allocatedLandedCost = landedCosts * proportion;
        double landedCostPerUnit = item.quantity.value > 0 ? allocatedLandedCost / item.quantity.value : 0;
        
        // Final Unit Cost = Purchase Price + Landed Cost per Unit
        double finalUnitCost = item.price.value + landedCostPerUnit;

        await into(purchaseItems).insert(item);

        // Update Stock (Increase) if status is RECEIVED
        if (finalPurchaseCompanion.status.value == 'RECEIVED') {
          final product = await (select(
            products,
          )..where((p) => p.id.equals(item.productId.value))).getSingle();

          double quantityToAdd = item.quantity.value;
          if (item.isCarton.value) {
            quantityToAdd *= product.piecesPerCarton;
          }

          await (update(
            products,
          )..where((p) => p.id.equals(item.productId.value))).write(
            ProductsCompanion(
              stock: Value(product.stock + quantityToAdd),
              buyPrice: Value(finalUnitCost), // Update buy price to include landed costs
            ),
          );

          // Create Product Batch
          await into(productBatches).insert(
            ProductBatchesCompanion.insert(
              id: Value(const Uuid().v4()),
              productId: item.productId.value,
              warehouseId: finalPurchaseCompanion.warehouseId.value ?? '',
              batchNumber: 'PUR-${DateTime.now().millisecondsSinceEpoch}',
              quantity: Value(quantityToAdd),
              initialQuantity: Value(quantityToAdd),
              costPrice: Value(finalUnitCost),
              syncStatus: const Value(1),
            ),
          );
        }
      }

      // 3. Update Supplier Balance if Credit
      if (finalPurchaseCompanion.isCredit.value &&
          finalPurchaseCompanion.supplierId.value != null) {
        final supplier =
            await (select(suppliers)..where(
                  (s) => s.id.equals(finalPurchaseCompanion.supplierId.value!),
                ))
                .getSingle();
        await (update(suppliers)..where(
              (s) => s.id.equals(finalPurchaseCompanion.supplierId.value!),
            ))
            .write(
              SuppliersCompanion(
                balance: Value(
                  supplier.balance + finalPurchaseCompanion.total.value,
                ),
              ),
            );
      }

      // 4. Accounting (via Event Bus)
      final purchaseObj =
          await (select(purchases)
                ..where((p) => p.id.equals(finalPurchaseCompanion.id.value)))
              .getSingle();
      final insertedItems =
          await (select(purchaseItems)..where(
                (pi) => pi.purchaseId.equals(finalPurchaseCompanion.id.value),
              ))
              .get();
      _eventBus.fire(
        PurchaseCreatedEvent(purchaseObj, insertedItems, userId: userId),
      );

      // 5. Audit Log
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'PURCHASES',
          entityId: purchaseCompanion.id.value,
          details: Value('Created purchase: ${purchaseCompanion.id.value}'),
        ),
      );
    });
  }

  Future<void> createPurchaseReturn({
    required PurchaseReturnsCompanion returnCompanion,
    required List<PurchaseReturnItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    return transaction(() async {
      // 1. Insert Purchase Return
      final returnId = returnCompanion.id.value;
      await into(purchaseReturns).insert(returnCompanion);

      // 2. Process Items
      for (var item in itemsCompanions) {
        await into(purchaseReturnItems).insert(item);

        // Update Stock (Decrease)
        final product = await (select(
          products,
        )..where((p) => p.id.equals(item.productId.value))).getSingle();
        await (update(
          products,
        )..where((p) => p.id.equals(item.productId.value))).write(
          ProductsCompanion(stock: Value(product.stock - item.quantity.value)),
        );
      }

      // 3. Update Supplier Balance if Credit
      final originalPurchase =
          await (select(purchases)
                ..where((p) => p.id.equals(returnCompanion.purchaseId.value)))
              .getSingle();
      if (originalPurchase.isCredit && originalPurchase.supplierId != null) {
        final supplier = await (select(
          suppliers,
        )..where((s) => s.id.equals(originalPurchase.supplierId!))).getSingle();
        await (update(
          suppliers,
        )..where((s) => s.id.equals(originalPurchase.supplierId!))).write(
          SuppliersCompanion(
            balance: Value(
              supplier.balance - returnCompanion.amountReturned.value,
            ),
          ),
        );
      }

      // 4. Accounting (via Event Bus)
      final returnObj = await (select(
        purchaseReturns,
      )..where((p) => p.id.equals(returnId))).getSingle();
      final insertedItems = await (select(
        purchaseReturnItems,
      )..where((pi) => pi.purchaseReturnId.equals(returnId))).get();
      _eventBus.fire(
        PurchaseReturnCreatedEvent(returnObj, insertedItems, userId: userId),
      );

      // 5. Audit Log
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'PURCHASE_RETURNS',
          entityId: returnId,
          details: Value(
            'Created purchase return: $returnId for purchase: ${returnCompanion.purchaseId.value}',
          ),
        ),
      );
    });
  }
}
