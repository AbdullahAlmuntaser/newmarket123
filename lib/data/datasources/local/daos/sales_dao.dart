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
    ])
      ..where(sales.createdAt.isBiggerOrEqual(Variable(startOfDay)));

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

  Future<List<Sale>> getInvoicesByDateRange(DateTime startDate, DateTime endDate) {
    return (select(sales)
          ..where((s) =>
              s.createdAt.isBiggerOrEqualValue(startDate) &
              s.createdAt.isSmallerOrEqualValue(endDate))
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
    final productIds =
        rows.map((row) => row.read(saleItems.productId)!).toList();

    if (productIds.isEmpty) return [];

    return (select(db.products)..where((p) => p.id.isIn(productIds))).get();
  }

  Future<List<TopProduct>> getTopSellingProducts({int limit = 5}) async {
    final quantitySum = saleItems.quantity.sum();
    final query = select(saleItems).join([
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
    ])
      ..addColumns([quantitySum])
      ..groupBy([saleItems.productId])
      ..orderBy([OrderingTerm.desc(quantitySum)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map((row) {
      return TopProduct(
        product: row.readTable(products),
        totalQuantity: row.read(quantitySum) ?? 0.0,
      );
    }).toList();
  }

  Future<List<ProductProfitability>> getProductProfitability({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final reportStartDate = startDate ?? DateTime(2000);
    final reportEndDate = endDate ?? DateTime.now();

    final revenueSum = (saleItems.quantity * saleItems.price).sum();
    final costSum = (saleItems.quantity * products.buyPrice).sum();
    final quantitySum = saleItems.quantity.sum();

    final query = select(saleItems).join([
      innerJoin(sales, sales.id.equalsExp(saleItems.saleId)),
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
    ])
      ..addColumns([revenueSum, costSum, quantitySum])
      ..where(sales.createdAt
          .isBetween(Variable(reportStartDate), Variable(reportEndDate)))
      ..groupBy([saleItems.productId]);

    final rows = await query.get();

    return rows.map((row) {
      final product = row.readTable(products);
      final revenue = row.read(revenueSum) ?? 0.0;
      final cost = row.read(costSum) ?? 0.0;

      return ProductProfitability(
        productId: product.id,
        productName: product.name,
        totalQuantity: row.read(quantitySum) ?? 0.0,
        totalRevenue: revenue,
        totalCost: cost,
      );
    }).toList()
      ..sort((a, b) => b.netProfit.compareTo(a.netProfit));
  }

  // ==================== Sales Orders Management ====================
  // إدارة طلبات المبيعات (Sales Orders)

  Future<List<SalesOrder>> getAllSalesOrders() async {
    return (select(salesOrders)).get();
  }

  Future<SalesOrder?> getSalesOrderById(String orderId) async {
    return (select(salesOrders)..where((o) => o.id.equals(orderId)))
        .getSingleOrNull();
  }

  Future<List<SalesOrderItem>> getSalesOrderItems(String orderId) async {
    return (select(salesOrderItems)..where((i) => i.orderId.equals(orderId)))
        .get();
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
      await (delete(salesOrderItems)..where((i) => i.orderId.equals(orderId)))
          .go();
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

  Future<void> deleteSale(String saleId) async {
    return transaction(() async {
      await (delete(saleItems)..where((i) => i.saleId.equals(saleId))).go();
      await (delete(sales)..where((s) => s.id.equals(saleId))).go();

      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          action: 'DELETE',
          targetEntity: 'SALES_INVOICE',
          entityId: saleId,
          details: Value('Deleted sales invoice: $saleId'),
        ),
      );
    });
  }

  Future<void> updateSale({
    required String saleId,
    required SalesCompanion saleCompanion,
    required List<SaleItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    return transaction(() async {
      await (update(sales)..where((s) => s.id.equals(saleId)))
          .write(saleCompanion);

      await (delete(saleItems)..where((i) => i.saleId.equals(saleId))).go();
      for (var item in itemsCompanions) {
        await into(saleItems).insert(item);
      }

      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'UPDATE',
          targetEntity: 'SALES_INVOICE',
          entityId: saleId,
          details: Value('Updated sales invoice: $saleId'),
        ),
      );
    });
  }

  Future<List<SalesOrder>> getSalesOrdersByCustomer(String customerId) async {
    return (select(salesOrders)..where((o) => o.customerId.equals(customerId)))
        .get();
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
