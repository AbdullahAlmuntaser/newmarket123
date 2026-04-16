import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class BomDao extends DatabaseAccessor<AppDatabase> {
  BomDao(super.db);

  Future<List<BillOfMaterial>> getBomForProduct(String productId) {
    return (select(
      db.billOfMaterials,
    )..where((b) => b.finishedProductId.equals(productId))).get();
  }

  Future<List<BillOfMaterial>> getAllBoms() {
    return (select(
      db.billOfMaterials,
    )..orderBy([(b) => OrderingTerm.asc(b.finishedProductId)])).get();
  }

  Future<List<BillOfMaterial>> getBomsWhereComponentIs(String componentId) {
    return (select(
      db.billOfMaterials,
    )..where((b) => b.componentProductId.equals(componentId))).get();
  }

  Future<int> insertBom(
    String finishedProductId,
    String componentProductId,
    double quantity,
  ) {
    return into(db.billOfMaterials).insert(
      BillOfMaterialsCompanion.insert(
        finishedProductId: finishedProductId,
        componentProductId: componentProductId,
        quantity: quantity,
      ),
    );
  }

  Future<int> updateBom(String id, double quantity) {
    return (update(db.billOfMaterials)..where((b) => b.id.equals(id))).write(
      BillOfMaterialsCompanion(quantity: Value(quantity)),
    );
  }

  Future<int> deleteBom(String id) {
    return (delete(db.billOfMaterials)..where((b) => b.id.equals(id))).go();
  }

  Future<int> deleteAllBomsForProduct(String productId) {
    return (delete(
      db.billOfMaterials,
    )..where((b) => b.finishedProductId.equals(productId))).go();
  }
}
