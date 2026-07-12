part of '../app_database.dart';

class WithholdingTaxEntries extends Table with SyncableTable {
  TextColumn get paymentId => text()();
  TextColumn get paymentType => text()(); // SUPPLIER_PAYMENT
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get grossAmount => text().map(const DecimalConverter())();
  TextColumn get taxRate => text().map(const DecimalConverter())();
  TextColumn get taxAmount => text().map(const DecimalConverter())();
  TextColumn get netAmount => text().map(const DecimalConverter())();
  DateTimeColumn get taxDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING/FILED/PAID
  TextColumn get referenceNumber => text().nullable()();
}

class SerialNumbers extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get serialNumber => text().unique()();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get status => text().withDefault(const Constant('IN_STOCK'))(); // IN_STOCK/SOLD/RESERVED/RETURNED
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
  TextColumn get referenceId => text().nullable()(); // Sale or Purchase ID
  DateTimeColumn get receivedDate => dateTime().nullable()();
  DateTimeColumn get soldDate => dateTime().nullable()();
}
