// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bom_dao.dart';

// ignore_for_file: type=lint
mixin _$BomDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $BillOfMaterialsTable get billOfMaterials => attachedDatabase.billOfMaterials;
  BomDaoManager get managers => BomDaoManager(this);
}

class BomDaoManager {
  final _$BomDaoMixin _db;
  BomDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$BillOfMaterialsTableTableManager get billOfMaterials =>
      $$BillOfMaterialsTableTableManager(
        _db.attachedDatabase,
        _db.billOfMaterials,
      );
}
