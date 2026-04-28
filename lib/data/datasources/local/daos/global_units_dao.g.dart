// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'global_units_dao.dart';

// ignore_for_file: type=lint
mixin _$GlobalUnitsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BranchesTable get branches => attachedDatabase.branches;
  $GlobalUnitsTable get globalUnits => attachedDatabase.globalUnits;
  GlobalUnitsDaoManager get managers => GlobalUnitsDaoManager(this);
}

class GlobalUnitsDaoManager {
  final _$GlobalUnitsDaoMixin _db;
  GlobalUnitsDaoManager(this._db);
  $$BranchesTableTableManager get branches =>
      $$BranchesTableTableManager(_db.attachedDatabase, _db.branches);
  $$GlobalUnitsTableTableManager get globalUnits =>
      $$GlobalUnitsTableTableManager(_db.attachedDatabase, _db.globalUnits);
}
