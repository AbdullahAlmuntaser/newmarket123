part of '../app_database.dart';

class ZakatCalculations extends Table with SyncableTable {
  TextColumn get period => text()(); // "2024" or "2024-Q1"
  TextColumn get calculationType => text()(); // ANNUAL/QUARTERLY
  TextColumn get totalAssets => text().map(const DecimalConverter())();
  TextColumn get totalLiabilities => text().map(const DecimalConverter())();
  TextColumn get zakatBase => text().map(const DecimalConverter())(); // Assets - Liabilities
  TextColumn get zakatRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.parse('0.025').toString()))(); // 2.5%
  TextColumn get zakatAmount => text().map(const DecimalConverter())();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))(); // DRAFT/FILED/PAID
  DateTimeColumn get calculationDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}

class EndOfServiceBenefits extends Table with SyncableTable {
  TextColumn get employeeId => text().references(Employees, #id)();
  DateTimeColumn get hireDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get lastSalary => text().map(const DecimalConverter())();
  IntColumn get totalYearsOfService => integer()();
  TextColumn get eosbAmount => text().map(const DecimalConverter())();
  TextColumn get calculationMethod => text().withDefault(const Constant('STANDARD'))(); // STANDARD/ENHANCED
  TextColumn get status => text().withDefault(const Constant('CALCULATED'))(); // CALCULATED/PAID/VOIDED
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}

class InventoryReservations extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get referenceType => text()(); // SALES_ORDER/PURCHASE_ORDER/PRODUCTION
  TextColumn get referenceId => text()();
  TextColumn get reservedQuantity => text().map(const DecimalConverter())();
  TextColumn get fulfilledQuantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))(); // ACTIVE/PARTIAL/COMPLETED/CANCELLED
  DateTimeColumn get reservationDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiryDate => dateTime().nullable()();
}
