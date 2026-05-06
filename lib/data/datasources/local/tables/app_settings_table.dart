import 'package:drift/drift.dart';

@DataClassName('AppSetting')
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get description => text().nullable()();
  
  @override
  List<Set<Column>> get uniqueKeys => [{key}];
}
