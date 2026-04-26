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
  )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  Future<List<StockMovement>> getAllStockMovements() =>
      select(stockMovements).get();
  Future<bool> updateStockMovement(StockMovement entry) =>
      update(stockMovements).replace(entry);
  Future<int> deleteStockMovement(String id) =>
      (delete(stockMovements)..where((tbl) => tbl.id.equals(id))).go();
  Future<List<StockMovement>> getStockMovementsByProduct(String productId) =>
      (select(
        stockMovements,
      )..where((tbl) => tbl.productId.equals(productId))).get();
}
