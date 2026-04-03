// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products_dao.dart';

// ignore_for_file: type=lint
mixin _$ProductsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $ProductBatchesTable get productBatches => attachedDatabase.productBatches;
  $StockTransfersTable get stockTransfers => attachedDatabase.stockTransfers;
  $StockTransferItemsTable get stockTransferItems =>
      attachedDatabase.stockTransferItems;
  ProductsDaoManager get managers => ProductsDaoManager(this);
}

class ProductsDaoManager {
  final _$ProductsDaoMixin _db;
  ProductsDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$ProductBatchesTableTableManager get productBatches =>
      $$ProductBatchesTableTableManager(
        _db.attachedDatabase,
        _db.productBatches,
      );
  $$StockTransfersTableTableManager get stockTransfers =>
      $$StockTransfersTableTableManager(
        _db.attachedDatabase,
        _db.stockTransfers,
      );
  $$StockTransferItemsTableTableManager get stockTransferItems =>
      $$StockTransferItemsTableTableManager(
        _db.attachedDatabase,
        _db.stockTransferItems,
      );
}
