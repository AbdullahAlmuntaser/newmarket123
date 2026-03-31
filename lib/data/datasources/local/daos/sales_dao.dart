import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'sales_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleItems])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

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

  Stream<int> watchTotalSalesToday() {
    final query = select(sales)
      ..where(
        (s) => s.createdAt.isBiggerOrEqualValue(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
    return query.watch().map((rows) => rows.length);
  }

  Future<List<Sale>> getSalesForCustomer(String customerId) {
    return (select(sales)..where((s) => s.customerId.equals(customerId))).get();
  }

  Future<List<TopProduct>> getTopSellingProducts({int limit = 5}) async {
    final quantity = saleItems.quantity.sum();
    final query = select(saleItems).join([
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
    ]);

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
