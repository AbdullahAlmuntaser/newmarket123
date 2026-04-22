import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'warehouses_dao.g.dart';

@DriftAccessor(tables: [Warehouses, ProductBatches])
class WarehousesDao extends DatabaseAccessor<AppDatabase> with _$WarehousesDaoMixin {
  WarehousesDao(super.db);

  Future<List<Warehouse>> getAllWarehouses() => select(warehouses).get();

  Stream<List<Warehouse>> watchWarehouses() => select(warehouses).watch();

  Future<Warehouse?> getWarehouseById(String id) =>
      (select(warehouses)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createWarehouse(WarehousesCompanion warehouse) =>
      into(warehouses).insert(warehouse);

  Future<bool> updateWarehouse(Warehouse warehouse) =>
      update(warehouses).replace(warehouse);

  Future<int> deleteWarehouse(String id) =>
      (delete(warehouses)..where((t) => t.id.equals(id))).go();

  Future<bool> hasStock(String warehouseId) async {
    final query = select(productBatches)
      ..where((t) => t.warehouseId.equals(warehouseId) & t.quantity.isBiggerThanValue(0));
    final results = await query.get();
    return results.isNotEmpty;
  }

  Future<void> setDefaultWarehouse(String id) async {
    await transaction(() async {
      await (update(warehouses)..where((t) => t.isDefault.equals(true)))
          .write(const WarehousesCompanion(isDefault: Value(false)));
      await (update(warehouses)..where((t) => t.id.equals(id)))
          .write(const WarehousesCompanion(isDefault: Value(true)));
    });
  }
}
