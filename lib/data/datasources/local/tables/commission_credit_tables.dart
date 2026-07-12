part of '../app_database.dart';

class CreditNotes extends Table with SyncableTable {
  TextColumn get invoiceNumber => text().unique()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get totalAmount => text().map(const DecimalConverter())();
  TextColumn get taxAmount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get reason => text()();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))(); // DRAFT/POSTED/VOIDED
  DateTimeColumn get creditNoteDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get postedBy => text().nullable()();
  DateTimeColumn get postedAt => dateTime().nullable()();
}

class CreditNoteItems extends Table with SyncableTable {
  TextColumn get creditNoteId => text().references(CreditNotes, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get unitPrice => text().map(const DecimalConverter())();
  TextColumn get total => text().map(const DecimalConverter())();
}

class SalesTargets extends Table with SyncableTable {
  TextColumn get salespersonId => text()();
  TextColumn get period => text()(); // "2024-01" or "2024-Q1"
  TextColumn get targetAmount => text().map(const DecimalConverter())();
  TextColumn get actualAmount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get commissionRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))(); // ACTIVE/ACHIEVED/EXPIRED
}

class SalesCommissions extends Table with SyncableTable {
  TextColumn get salespersonId => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get saleAmount => text().map(const DecimalConverter())();
  TextColumn get commissionRate => text().map(const DecimalConverter())();
  TextColumn get commissionAmount => text().map(const DecimalConverter())();
  TextColumn get period => text()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING/PAID/VOIDED
  DateTimeColumn get paidAt => dateTime().nullable()();
}
