import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'global_units_dao.g.dart';

@DriftAccessor(tables: [GlobalUnits])
class GlobalUnitsDao extends DatabaseAccessor<AppDatabase>
    with _$GlobalUnitsDaoMixin {
  GlobalUnitsDao(super.db);

  Future<List<GlobalUnit>> getAllUnits() => select(globalUnits).get();

  Stream<List<GlobalUnit>> watchAllUnits() => select(globalUnits).watch();

  Future<int> addUnit(GlobalUnitsCompanion unit) =>
      into(globalUnits).insert(unit);

  Future<bool> updateUnit(GlobalUnit unit) => update(globalUnits).replace(unit);

  Future<int> deleteUnit(String id) =>
      (delete(globalUnits)..where((t) => t.id.equals(id))).go();
}
