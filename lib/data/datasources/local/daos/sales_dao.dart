import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';

part 'sales_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleItems, Products, Customers, SyncQueue, AuditLogs, SalesReturns, SalesReturnItems])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

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
    return transaction(() async {
      // 1. Insert Sale
      await into(sales).insert(saleCompanion);

      // 2. Process Items
      for (var item in itemsCompanions) {
        await into(saleItems).insert(item);

        // Update Stock (Decrease)
        final product = await (select(products)..where((p) => p.id.equals(item.productId.value))).getSingle();
        
        double quantityToDecrease = item.quantity.value;
        if (item.isCarton.value) {
          quantityToDecrease *= product.piecesPerCarton;
        }

        await (update(products)..where((p) => p.id.equals(item.productId.value))).write(
          ProductsCompanion(stock: Value(product.stock - quantityToDecrease)),
        );
      }

      // 3. Update Customer Balance if Credit
      if (saleCompanion.isCredit.value && saleCompanion.customerId.value != null) {
        final customer = await (select(customers)..where((c) => c.id.equals(saleCompanion.customerId.value!))).getSingle();
        await (update(customers)..where((c) => c.id.equals(saleCompanion.customerId.value!))).write(
          CustomersCompanion(balance: Value(customer.balance + saleCompanion.total.value)),
        );
      }

      // 4. Accounting
      final saleObj = await (select(sales)..where((s) => s.id.equals(saleCompanion.id.value))).getSingle();
      final accounting = AccountingService(db);
      final insertedItems = await (select(saleItems)..where((si) => si.saleId.equals(saleCompanion.id.value))).get();
      await accounting.postSale(saleObj, insertedItems);

      // 5. Audit Log
      await into(auditLogs).insert(AuditLogsCompanion.insert(
        userId: Value(userId),
        action: 'CREATE',
        targetEntity: 'SALES',
        entityId: saleCompanion.id.value,
        details: Value('Created sale: ${saleCompanion.id.value}'),
      ));
    });
  }

  Future<void> createSaleReturn({
    required SalesReturnsCompanion returnCompanion,
    required List<SalesReturnItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    return transaction(() async {
      // 1. Insert Sales Return
      final returnId = await into(salesReturns).insert(returnCompanion);

      // 2. Process Items
      for (var item in itemsCompanions) {
        await into(salesReturnItems).insert(item.copyWith(salesReturnId: Value(returnId as String)));

        // Update Stock (Increase)
        final product = await (select(products)..where((p) => p.id.equals(item.productId.value))).getSingle();
        await (update(products)..where((p) => p.id.equals(item.productId.value))).write(
          ProductsCompanion(stock: Value(product.stock + item.quantity.value)),
        );
      }

      // 3. Update Customer Balance if Credit
      final originalSale = await (select(sales)..where((s) => s.id.equals(returnCompanion.saleId.value))).getSingle();
      if (originalSale.isCredit && originalSale.customerId != null) {
        final customer = await (select(customers)..where((c) => c.id.equals(originalSale.customerId!))).getSingle();
        await (update(customers)..where((c) => c.id.equals(originalSale.customerId!))).write(
          CustomersCompanion(balance: Value(customer.balance - returnCompanion.amountReturned.value)),
        );
      }

      // 4. Accounting
      final returnObj = await (select(salesReturns)..where((s) => s.id.equals(returnId as String))).getSingle();
      final accounting = AccountingService(db);
      final insertedItems = await (select(salesReturnItems)..where((si) => si.salesReturnId.equals(returnId as String))).get();
      await accounting.postSaleReturn(returnObj, insertedItems);

      // 5. Audit Log
      await into(auditLogs).insert(AuditLogsCompanion.insert(
        userId: Value(userId),
        action: 'CREATE',
        targetEntity: 'SALES_RETURNS',
        entityId: returnId as String,
        details: Value('Created sales return: $returnId for sale: ${returnCompanion.saleId.value}'),
      ));
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
