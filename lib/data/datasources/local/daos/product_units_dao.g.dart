// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_units_dao.dart';

// ignore_for_file: type=lint
mixin _$ProductUnitsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $ProductUnitsTable get productUnits => attachedDatabase.productUnits;
  ProductUnitsDaoManager get managers => ProductUnitsDaoManager(this);
}

class ProductUnitsDaoManager {
  final _$ProductUnitsDaoMixin _db;
  ProductUnitsDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$ProductUnitsTableTableManager get productUnits =>
      $$ProductUnitsTableTableManager(_db.attachedDatabase, _db.productUnits);
}
