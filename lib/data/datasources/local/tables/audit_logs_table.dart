import 'package:drift/drift.dart';

class AuditLogsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get oldValues => text()();
  TextColumn get newValues => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}
