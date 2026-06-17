import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

// جدول العملات
class AccCurrencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 3, max: 3)(); // USD, SAR, EUR
  TextColumn get name => text().withLength(min: 2, max: 50)();
  TextColumn get exchangeRate =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))(); // مقابل العملة الأساسية
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول أسعار الصرف
class AccExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('accExchangeRatesFrom')
  IntColumn get fromCurrencyId => integer().references(AccCurrencies, #id)();
  @ReferenceName('accExchangeRatesTo')
  IntColumn get toCurrencyId => integer().references(AccCurrencies, #id)();
  TextColumn get rate => text().map(const DecimalConverter())();
  DateTimeColumn get effectiveDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول الميزانيات التقديرية
class AccBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 2, max: 100)();
  TextColumn get period => text()(); // "2024", "2024-Q1"
  TextColumn get costCenterId =>
      text().nullable().references(CostCenters, #id)();
  TextColumn get accountId =>
      text().nullable().references(GLAccounts, #id)(); // ربط بحساب محدد
  TextColumn get budgetedAmount => text().map(const DecimalConverter())();
  TextColumn get actualAmount =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // يُحدث تلقائياً من القيود
  TextColumn get variance => text().map(const DecimalConverter())(); // يمكن حسابها برمجياً
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active, closed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول كشف الحساب البنكي
class AccBankStatements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountId =>
      text().references(GLAccounts, #id)(); // ربط بحساب البنك
  TextColumn get statementReference => text().nullable()();
  DateTimeColumn get statementDate => dateTime()();
  TextColumn get openingBalance => text().map(const DecimalConverter())();
  TextColumn get closingBalance => text().map(const DecimalConverter())();
  TextColumn get currency => text().withDefault(const Constant('SAR'))();
  TextColumn get status =>
      text().withDefault(const Constant('imported'))(); // imported, reconciled
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول حركات كشف الحساب البنكي
class AccBankStatementLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get statementId => integer().references(AccBankStatements, #id)();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get description => text()();
  TextColumn get debit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get credit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get balance => text().map(const DecimalConverter()).nullable()();
  TextColumn get reference => text().nullable()();
  TextColumn get matchedJournalEntryId =>
      text().nullable().references(GLEntries, #id)(); // ربط بالقيد المطابق
  TextColumn get reconciliationStatus => text().withDefault(
      const Constant('unreconciled'))(); // unreconciled, matched, cleared
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول سجل التدقيقات (Audit Log) - نسخة متقدمة
class AccAuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get logTableName => text()();
  TextColumn get recordId => text()(); // Changed to Text to match SyncableTable IDs
  TextColumn get action => text()(); // INSERT, UPDATE, DELETE
  TextColumn get oldValues => text().nullable()(); // JSON
  TextColumn get newValues => text().nullable()(); // JSON
  TextColumn get userId => text().nullable().references(Users, #id)();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get ipAddress => text().nullable()();
}
