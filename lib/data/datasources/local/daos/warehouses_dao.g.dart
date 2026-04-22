// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warehouses_dao.dart';

// ignore_for_file: type=lint
mixin _$WarehousesDaoMixin on DatabaseAccessor<AppDatabase> {
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $ProductBatchesTable get productBatches => attachedDatabase.productBatches;
  WarehousesDaoManager get managers => WarehousesDaoManager(this);
}

class WarehousesDaoManager {
  final _$WarehousesDaoMixin _db;
  WarehousesDaoManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$ProductBatchesTableTableManager get productBatches =>
      $$ProductBatchesTableTableManager(
        _db.attachedDatabase,
        _db.productBatches,
      );
}
