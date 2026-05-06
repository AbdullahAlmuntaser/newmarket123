import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

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
    SalesOrders,
    SalesOrderItems,
  ],
)
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
    ])..where(sales.createdAt.isBiggerOrEqual(Variable(startOfDay)));

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

  Future<List<Sale>> getInvoicesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return (select(sales)
      ..where((s) => s.createdAt.isBiggerOrEqualValue(startDate) & s.createdAt.isSmallerOrEqualValue(endDate))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
    .get();
  }

  Future<List<SaleItem>> getInvoiceItems(String saleId) {
    return (select(saleItems)..where((si) => si.saleId.equals(saleId))).get();
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
      // 1. Insert Sale
      final saleId = saleCompanion.id.value;
      await into(sales).insert(saleCompanion);

      // 2. Insert Items
      for (var item in itemsCompanions) {
        await into(saleItems).insert(item);
      }

      // 3. Audit Log
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'SALES',
          entityId: saleId,
          details: Value('Created sale record: $saleId'),
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
      final returnId = returnCompanion.id.value;
      await into(salesReturns).insert(returnCompanion);

      for (var item in itemsCompanions) {
        await into(salesReturnItems).insert(item);
      }

      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'SALES_RETURNS',
          entityId: returnId,
          details: Value(
            'Created sales return record: $returnId for sale: ${returnCompanion.saleId.value}',
          ),
        ),
      );
    });
  }

  Future<List<Product>> getMostSoldProducts({int limit = 10}) async {
    final query = selectOnly(saleItems)
      ..addColumns([saleItems.productId, saleItems.quantity.sum()])
      ..groupBy([saleItems.productId])
      ..orderBy([OrderingTerm.desc(saleItems.quantity.sum())])
      ..limit(limit);

    final rows = await query.get();
    final productIds = rows
        .map((row) => row.read(saleItems.productId)!)
        .toList();

    if (productIds.isEmpty) return [];

    return (select(db.products)..where((p) => p.id.isIn(productIds))).get();
  }

  Future<List<ProductProfitability>> getProductProfitability({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final reportStartDate = startDate ?? DateTime(2000);
    final reportEndDate = endDate ?? DateTime.now();

    final query = select(saleItems).join([
      innerJoin(sales, sales.id.equalsExp(saleItems.saleId)),
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
    ])..where(sales.createdAt.isBetween(Variable(reportStartDate), Variable(reportEndDate)));

    final rows = await query.get();
    final Map<String, ProductProfitability> profitabilityMap = {};

    for (final row in rows) {
      final item = row.readTable(saleItems);
      final product = row.readTable(products);

      final revenue = item.quantity * item.price;
      // Use product buyPrice as fallback, though batches are more accurate
      final cost = item.quantity * product.buyPrice;

      if (profitabilityMap.containsKey(product.id)) {
        final current = profitabilityMap[product.id]!;
        profitabilityMap[product.id] = ProductProfitability(
          productId: product.id,
          productName: product.name,
          totalQuantity: current.totalQuantity + item.quantity,
          totalRevenue: current.totalRevenue + revenue,
          totalCost: current.totalCost + cost,
        );
      } else {
        profitabilityMap[product.id] = ProductProfitability(
          productId: product.id,
          productName: product.name,
          totalQuantity: item.quantity,
          totalRevenue: revenue,
          totalCost: cost,
        );
      }
    }

    return profitabilityMap.values.toList()
      ..sort((a, b) => b.netProfit.compareTo(a.netProfit));
  }

  Future<List<TopProduct>> getTopSellingProducts({int limit = 5}) async {
    final query = select(
      saleItems,
    ).join([innerJoin(products, products.id.equalsExp(saleItems.productId))]);

    final rows = await query.get();
    final Map<String, TopProduct> topProductsMap = {};

    for (final row in rows) {
      final item = row.readTable(saleItems);
      final product = row.readTable(products);

      if (topProductsMap.containsKey(product.id)) {
        final current = topProductsMap[product.id]!;
        topProductsMap[product.id] = TopProduct(
          product: product,
          totalQuantity: current.totalQuantity + item.quantity,
        );
      } else {
        topProductsMap[product.id] = TopProduct(
          product: product,
          totalQuantity: item.quantity,
        );
      }
    }

    final list = topProductsMap.values.toList()
      ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    return list.take(limit).toList();
  }

  // ==================== Sales Orders Management ====================
  // إدارة طلبات المبيعات (Sales Orders)

  Future<List<SalesOrder>> getAllSalesOrders() async {
    return (select(salesOrders)).get();
  }

  Future<SalesOrder?> getSalesOrderById(String orderId) async {
    return (select(salesOrders)..where((o) => o.id.equals(orderId))).getSingleOrNull();
  }

  Future<List<SalesOrderItem>> getSalesOrderItems(String orderId) async {
    return (select(salesOrderItems)..where((i) => i.orderId.equals(orderId))).get();
  }

  Future<void> createSalesOrder({
    required SalesOrdersCompanion orderCompanion,
    required List<SalesOrderItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    if (itemsCompanions.isEmpty) {
      throw Exception('لا يمكن إنشاء طلب بيع بدون أصناف.');
    }

    return transaction(() async {
      final orderId = orderCompanion.id.value;
      await into(salesOrders).insert(orderCompanion);

      for (var item in itemsCompanions) {
        await into(salesOrderItems).insert(item);
      }

      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'CREATE',
          targetEntity: 'SALES_ORDER',
          entityId: orderId,
          details: Value('Created sales order: $orderId'),
        ),
      );
    });
  }

  Future<void> updateSalesOrderStatus(String orderId, String newStatus) async {
    return transaction(() async {
      await (update(salesOrders)..where((o) => o.id.equals(orderId))).write(
        SalesOrdersCompanion(status: Value(newStatus)),
      );

      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          action: 'UPDATE',
          targetEntity: 'SALES_ORDER',
          entityId: orderId,
          details: Value('Updated status to: $newStatus'),
        ),
      );
    });
  }

  Future<void> deleteSalesOrder(String orderId) async {
    return transaction(() async {
      await (delete(salesOrderItems)..where((i) => i.orderId.equals(orderId))).go();
      await (delete(salesOrders)..where((o) => o.id.equals(orderId))).go();

      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          action: 'DELETE',
          targetEntity: 'SALES_ORDER',
          entityId: orderId,
          details: const Value('Deleted sales order'),
        ),
      );
    });
  }

  Future<List<SalesOrder>> getSalesOrdersByCustomer(String customerId) async {
    return (select(salesOrders)..where((o) => o.customerId.equals(customerId))).get();
  }

  Future<List<SalesOrder>> getSalesOrdersByStatus(String status) async {
    return (select(salesOrders)..where((o) => o.status.equals(status))).get();
  }
}

class ProductProfitability {
  final String productId;
  final String productName;
  final double totalQuantity;
  final double totalRevenue;
  final double totalCost;

  double get netProfit => totalRevenue - totalCost;
  double get profitMargin =>
      totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;

  ProductProfitability({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.totalCost,
  });
}

class TopProduct {
  final Product product;
  final double totalQuantity;

  TopProduct({required this.product, required this.totalQuantity});
}
