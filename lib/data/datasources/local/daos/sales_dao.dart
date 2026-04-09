import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/injection_container.dart';

part 'sales_dao.g.dart';

@DriftAccessor(
  tables: [
    Sales,
    SaleItems,
    Products,
    Customers,
    SyncQueue,
    AuditLogs,
    SalesReturns,
    SalesReturnItems,
    ProductBatches,
  ],
)
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

  EventBusService get _eventBus => sl<EventBusService>();

  Stream<List<Sale>> watchAllSales() => select(sales).watch();

  Stream<List<SaleItem>> watchSaleItems(String saleId) {
    return (select(saleItems)..where((si) => si.saleId.equals(saleId))).watch();
  }

  Stream<double> watchTotalRevenueToday() {
    final query = select(sales)
      ..where(
        (s) => s.createdAt.isBiggerOrEqualValue(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
    return query.watch().map(
      (rows) => rows.fold(0.0, (sum, sale) => sum + sale.total),
    );
  }

  Stream<double> watchTotalSalesToday() {
    final query = select(sales)
      ..where(
        (s) => s.createdAt.isBiggerOrEqualValue(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
    return query.watch().map((rows) => rows.length.toDouble());
  }

  /// حساب أرباح اليوم
  Stream<double> watchTotalProfitToday() {
    final startOfDay = DateTime.now().subtract(const Duration(days: 1));
    final query = select(saleItems).join([
      innerJoin(sales, sales.id.equalsExp(saleItems.saleId)),
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
    ])..where(sales.createdAt.isBiggerOrEqualValue(startOfDay));

    return query.watch().map((rows) {
      double profit = 0;
      for (var row in rows) {
        final item = row.readTable(saleItems);
        final product = row.readTable(products);
        // الربح = (سعر البيع - سعر الشراء) * الكمية
        profit += (item.price - product.buyPrice) * item.quantity;
      }
      return profit;
    });
  }

  Future<List<Sale>> getSalesForCustomer(String customerId) {
    return (select(sales)..where((s) => s.customerId.equals(customerId))).get();
  }

  Future<Sale?> getSaleById(String id) {
    return (select(sales)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> createSale({
    required SalesCompanion saleCompanion,
    required List<SaleItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    if (itemsCompanions.isEmpty) {
      throw Exception('لا يمكن إنشاء فاتورة بدون أصناف.');
    }

    return transaction(() async {
      // Recalculate Totals from items to ensure accuracy
      double calculatedSubtotal = 0.0;
      for (var item in itemsCompanions) {
        calculatedSubtotal += item.quantity.value * item.price.value;
      }

      final discount = saleCompanion.discount.value;
      // Assume tax is calculated on (subtotal - discount)
      // Here we trust the tax rate from the product or a global one.
      // For now, we'll keep the tax passed but we could also derive it.
      final calculatedTax =
          (calculatedSubtotal - discount) * 0.15; // Example 15% tax
      final calculatedTotal = (calculatedSubtotal - discount) + calculatedTax;

      final finalSaleCompanion = saleCompanion.copyWith(
        total: Value(calculatedTotal),
        tax: Value(calculatedTax),
      );

      // 1. Insert Sale
      await into(sales).insert(finalSaleCompanion);

      // 2. Process Items
      for (var item in itemsCompanions) {
        final productId = item.productId.value;
        final product = await (select(
          products,
        )..where((p) => p.id.equals(productId))).getSingle();

        double quantityToDecrease = item.quantity.value;
        if (item.isCarton.value) {
          quantityToDecrease *= product.piecesPerCarton;
        }

        // Check Stock Availability
        if (product.stock < quantityToDecrease) {
          throw Exception(
            'الكمية المطلوبة من ${product.name} غير متوفرة. المتاح: ${product.stock}',
          );
        }

        await into(saleItems).insert(item);

        // Update Global Stock
        await (update(products)..where((p) => p.id.equals(productId))).write(
          ProductsCompanion(stock: Value(product.stock - quantityToDecrease)),
        );

        // FIFO: Update Product Batches
        double remainingToDeduct = quantityToDecrease;
        final batches =
            await (select(productBatches)
                  ..where(
                    (b) =>
                        b.productId.equals(productId) &
                        b.quantity.isBiggerThanValue(0),
                  )
                  ..orderBy([
                    (b) => OrderingTerm(
                      expression: b.createdAt,
                      mode: OrderingMode.asc,
                    ),
                  ]))
                .get();

        for (var batch in batches) {
          if (remainingToDeduct <= 0) break;
          double deduct = batch.quantity >= remainingToDeduct
              ? remainingToDeduct
              : batch.quantity;

          await (update(
            productBatches,
          )..where((b) => b.id.equals(batch.id))).write(
            ProductBatchesCompanion(quantity: Value(batch.quantity - deduct)),
          );
          remainingToDeduct -= deduct;
        }
      }

      // 3. Update Customer Balance if Credit
      if (finalSaleCompanion.isCredit.value &&
          finalSaleCompanion.customerId.value != null) {
        final customer =
            await (select(customers)..where(
                  (c) => c.id.equals(finalSaleCompanion.customerId.value!),
                ))
                .getSingle();
        await (update(customers)
              ..where((c) => c.id.equals(finalSaleCompanion.customerId.value!)))
            .write(
              CustomersCompanion(
                balance: Value(
                  customer.balance + finalSaleCompanion.total.value,
                ),
              ),
            );
      }

      // 4. Accounting (via Event Bus)
      final saleObj = await (select(
        sales,
      )..where((s) => s.id.equals(finalSaleCompanion.id.value))).getSingle();
      final insertedItems = await (select(
        saleItems,
      )..where((si) => si.saleId.equals(finalSaleCompanion.id.value))).get();
      _eventBus.fire(SaleCreatedEvent(saleObj, insertedItems, userId: userId));

      // 5. Audit Log
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'SALES',
          entityId: saleCompanion.id.value,
          details: Value('Created sale: ${saleCompanion.id.value}'),
        ),
      );
    });
  }

  Future<void> createSaleReturn({
    required SalesReturnsCompanion returnCompanion,
    required List<SalesReturnItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    return transaction(() async {
      // 1. Insert Sales Return
      final returnId = returnCompanion.id.value;
      await into(salesReturns).insert(returnCompanion);

      // 2. Process Items
      for (var item in itemsCompanions) {
        await into(salesReturnItems).insert(item);

        // Update Stock (Increase)
        final product = await (select(
          products,
        )..where((p) => p.id.equals(item.productId.value))).getSingle();
        await (update(
          products,
        )..where((p) => p.id.equals(item.productId.value))).write(
          ProductsCompanion(stock: Value(product.stock + item.quantity.value)),
        );

        // Find latest batch to return stock to (FIFO reverse)
        final latestBatch =
            await (select(productBatches)
                  ..where((t) => t.productId.equals(item.productId.value))
                  ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                  ..limit(1))
                .getSingleOrNull();

        if (latestBatch != null) {
          await (update(
            productBatches,
          )..where((t) => t.id.equals(latestBatch.id))).write(
            ProductBatchesCompanion(
              quantity: Value(latestBatch.quantity + item.quantity.value),
            ),
          );
        }
      }

      // 3. Update Customer Balance if Credit
      final originalSale = await (select(
        sales,
      )..where((s) => s.id.equals(returnCompanion.saleId.value))).getSingle();
      if (originalSale.isCredit && originalSale.customerId != null) {
        final customer = await (select(
          customers,
        )..where((c) => c.id.equals(originalSale.customerId!))).getSingle();
        await (update(
          customers,
        )..where((c) => c.id.equals(originalSale.customerId!))).write(
          CustomersCompanion(
            balance: Value(
              customer.balance - returnCompanion.amountReturned.value,
            ),
          ),
        );
      }

      // 4. Accounting (via Event Bus)
      final returnObj = await (select(
        salesReturns,
      )..where((s) => s.id.equals(returnId))).getSingle();
      final insertedItems = await (select(
        salesReturnItems,
      )..where((si) => si.salesReturnId.equals(returnId))).get();
      _eventBus.fire(
        SaleReturnCreatedEvent(returnObj, insertedItems, userId: userId),
      );

      // 5. Audit Log
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'SALES_RETURNS',
          entityId: returnId,
          details: Value(
            'Created sales return: $returnId for sale: ${returnCompanion.saleId.value}',
          ),
        ),
      );
    });
  }

  Future<List<TopProduct>> getTopSellingProducts({int limit = 5}) async {
    final quantity = saleItems.quantity.sum();
    final query = select(
      saleItems,
    ).join([innerJoin(products, products.id.equalsExp(saleItems.productId))]);

    query.addColumns([quantity]);
    query.groupBy([saleItems.productId]);
    query.orderBy([OrderingTerm.desc(quantity)]);
    query.limit(limit);

    final rows = await query.get();
    return rows.map((row) {
      return TopProduct(
        product: row.readTable(products),
        totalQuantity: row.read(quantity) ?? 0.0,
      );
    }).toList();
  }
}

class TopProduct {
  final Product product;
  final double totalQuantity;

  TopProduct({required this.product, required this.totalQuantity});
}
