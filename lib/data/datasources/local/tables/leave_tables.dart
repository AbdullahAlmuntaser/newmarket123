part of '../app_database.dart';

class LeaveTypes extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get code => text().unique()();
  IntColumn get defaultDays => integer().withDefault(const Constant(0))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class LeaveRequests extends Table with SyncableTable {
  TextColumn get employeeId => text().references(Employees, #id)();
  TextColumn get leaveTypeId => text().references(LeaveTypes, #id)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  IntColumn get totalDays => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING/APPROVED/REJECTED/CANCELLED
  TextColumn get approvedBy => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  TextColumn get rejectionReason => text().nullable()();
}

class LeaveBalances extends Table with SyncableTable {
  TextColumn get employeeId => text().references(Employees, #id)();
  TextColumn get leaveTypeId => text().references(LeaveTypes, #id)();
  IntColumn get year => integer()();
  IntColumn get entitled => integer().withDefault(const Constant(0))();
  IntColumn get taken => integer().withDefault(const Constant(0))();
  IntColumn get remaining => integer().withDefault(const Constant(0))();
}
