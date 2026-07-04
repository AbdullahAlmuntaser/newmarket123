part of '../app_database.dart';

class AttendanceRecords extends Table with SyncableTable {
  TextColumn get employeeId => text().references(Employees, #id)();
  DateTimeColumn get clockIn => dateTime()();
  DateTimeColumn get clockOut => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('PRESENT'))(); // PRESENT/ABSENT/LATE/EARLY_LEAVE/ON_LEAVE
  TextColumn get notes => text().nullable()();
  TextColumn get overtimeHours => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}
