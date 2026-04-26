import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'product_units_dao.g.dart';

@DriftAccessor(tables: [ProductUnits])
class ProductUnitsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductUnitsDaoMixin {
  ProductUnitsDao(super.db);

  Future<List<ProductUnit>> getAllProductUnits() => select(productUnits).get();

  Stream<List<ProductUnit>> watchAllProductUnits() =>
      select(productUnits).watch();

  Future<ProductUnit?> getProductUnitById(String id) async {
    return (select(
      productUnits,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<ProductUnit>> getUnitsForProduct(String productId) async {
    return (select(
      productUnits,
    )..where((tbl) => tbl.productId.equals(productId))).get();
  }

  Future<int> addProductUnit(ProductUnitsCompanion unit) =>
      into(productUnits).insert(unit);

  Future<bool> updateProductUnit(ProductUnitsCompanion unit, String id) {
    return (update(productUnits)..where((tbl) => tbl.id.equals(id)))
        .write(unit)
        .then((value) => value > 0);
  }

  Future<int> deleteProductUnit(String id) =>
      (delete(productUnits)..where((tbl) => tbl.id.equals(id))).go();
}
