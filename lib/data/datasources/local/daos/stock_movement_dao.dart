import 'package:drift/drift.dart';
import '../app_database.dart';

part 'stock_movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class StockMovementDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementDaoMixin {
  StockMovementDao(super.db);

  Future<int> insertStockMovement(StockMovementsCompanion entry) =>
      into(stockMovements).insert(entry);
  Future<StockMovement?> getStockMovementById(String id) => (select(
        stockMovements,
      )..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();
  Future<List<StockMovement>> getAllStockMovements() =>
      select(stockMovements).get();
  Future<bool> updateStockMovement(StockMovement entry) =>
      update(stockMovements).replace(entry);
  Future<int> deleteStockMovement(String id) =>
      (delete(stockMovements)..where((tbl) => tbl.id.equals(id))).go();
  Future<List<StockMovement>> getStockMovementsByProduct(String productId) =>
      (select(
        stockMovements,
      )..where((tbl) => tbl.productId.equals(productId)))
          .get();

  Future<List<StockMovement>> getProductMovementReport({
    required String productId,
    required DateTime startDate,
    required DateTime endDate,
    String? warehouseId,
  }) {
    var query = select(stockMovements)
      ..where((t) => t.productId.equals(productId))
      ..where((t) => t.movementDate.isBetweenValues(startDate, endDate));
    
    if (warehouseId != null) {
      query.where((t) => t.fromWarehouseId.equals(warehouseId) | t.toWarehouseId.equals(warehouseId));
    }
    
    return (query..orderBy([(t) => OrderingTerm(expression: t.movementDate)]))
        .get();
  }
}

