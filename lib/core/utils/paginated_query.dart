import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class PaginatedQuery {
  final AppDatabase db;

  PaginatedQuery(this.db);

  Future<List<Product>> getProducts({
    String? searchQuery,
    String? categoryId,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = db.select(db.products)
      ..where((p) {
        Expression<bool> condition = const Constant(true);
        if (searchQuery != null && searchQuery.isNotEmpty) {
          condition = condition &
              (p.name.like('%$searchQuery%') |
                  p.sku.like('%$searchQuery%') |
                  p.barcode.like('%$searchQuery%'));
        }
        if (categoryId != null) {
          condition = condition & p.categoryId.equals(categoryId);
        }
        return condition;
      })
      ..orderBy([(p) => OrderingTerm.asc(p.name)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<List<Sale>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = db.select(db.sales)
      ..where((s) {
        Expression<bool> condition = const Constant(true);
        if (startDate != null) {
          condition = condition & s.createdAt.isBiggerOrEqualValue(startDate);
        }
        if (endDate != null) {
          condition = condition & s.createdAt.isSmallerOrEqualValue(endDate);
        }
        if (customerId != null) {
          condition = condition & s.customerId.equals(customerId);
        }
        return condition;
      })
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<List<Purchase>> getPurchases({
    DateTime? startDate,
    DateTime? endDate,
    String? supplierId,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = db.select(db.purchases)
      ..where((p) {
        Expression<bool> condition = const Constant(true);
        if (startDate != null) {
          condition = condition & p.date.isBiggerOrEqualValue(startDate);
        }
        if (endDate != null) {
          condition = condition & p.date.isSmallerOrEqualValue(endDate);
        }
        if (supplierId != null) {
          condition = condition & p.supplierId.equals(supplierId);
        }
        return condition;
      })
      ..orderBy([(p) => OrderingTerm.desc(p.date)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<int> countProducts({String? searchQuery, String? categoryId}) async {
    var query = db.selectOnly(db.products)..addColumns([db.products.id]);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
        ..where(db.products.name.like('%$searchQuery%') |
            db.products.sku.like('%$searchQuery%'));
    }
    if (categoryId != null) {
      query = query..where(db.products.categoryId.equals(categoryId));
    }
    final results = await query.get();
    return results.length;
  }

  Future<List<SalesOrder>> getSalesOrders({
    String? status,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = db.select(db.salesOrders)
      ..where((o) {
        if (status != null && status != 'ALL') {
          return o.status.equals(status);
        }
        return const Constant(true);
      })
      ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
      ..limit(limit, offset: offset);
    return query.get();
  }
}
