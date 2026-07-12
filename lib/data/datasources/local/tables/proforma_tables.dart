part of '../app_database.dart';

class ProformaInvoices extends Table with SyncableTable {
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get total => text().map(const DecimalConverter())();
  TextColumn get discount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get tax => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  IntColumn get status => integer()
      .map(const DocumentStatusConverter())
      .withDefault(const Constant(0))();
  TextColumn get currencyId => text().nullable()();
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
  TextColumn get notes => text().nullable()();
  TextColumn get validUntil => text().nullable()(); //piry date
  TextColumn get convertedSaleId => text().nullable().references(Sales, #id)();
}

class ProformaInvoiceItems extends Table with SyncableTable {
  TextColumn get proformaId => text().references(ProformaInvoices, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get price => text().map(const DecimalConverter())();
  TextColumn get unitId => text().nullable().references(GlobalUnits, #id)();
  TextColumn get unitName => text().withDefault(const Constant('حبة'))();
  TextColumn get unitFactor => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
  TextColumn get discount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get taxRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}
