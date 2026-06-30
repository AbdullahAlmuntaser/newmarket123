part of '../app_database.dart';

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
      text().map(const DecimalConverter()).withDefault(
          Constant(Decimal.zero.toString()))(); // يُحدث تلقائياً من القيود
  TextColumn get variance =>
      text().map(const DecimalConverter())(); // يمكن حسابها برمجياً
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
  TextColumn get debit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get credit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get recordId =>
      text()(); // Changed to Text to match SyncableTable IDs
  TextColumn get action => text()(); // INSERT, UPDATE, DELETE
  TextColumn get oldValues => text().nullable()(); // JSON
  TextColumn get newValues => text().nullable()(); // JSON
  TextColumn get userId => text().nullable().references(Users, #id)();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get ipAddress => text().nullable()();
}

// Fixed assets are defined in tables/fixed_assets_tables.dart

// HR/Payroll tables are defined in tables/payroll_tables.dart

// جدول القيود المحاسبية الدورية (Recurring Journal Entries)
class RecurringEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // اسم القالب (مثال: "إيجار شهري")
  TextColumn get description => text().nullable()();
  TextColumn get referenceType => text()(); // EXPENSE, REVENUE, CUSTOM
  TextColumn get frequency =>
      text()(); // DAILY, WEEKLY, BIWEEKLY, MONTHLY, QUARTERLY, YEARLY
  TextColumn get debitAccountCode => text().references(GLAccounts, #code)();
  TextColumn get creditAccountCode => text().references(GLAccounts, #code)();
  TextColumn get amount => text().map(const DecimalConverter())();
  TextColumn get costCenterId =>
      text().nullable().references(CostCenters, #id)();
  TextColumn get branchId => text().nullable().references(Branches, #id)();
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active, paused, completed
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get nextExecutionDate => dateTime()();
  IntColumn get totalExecutions => integer().withDefault(const Constant(0))();
  IntColumn get maxExecutions => integer().nullable()(); // null = unlimited
  TextColumn get createdBy => text().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول سجل تنفيذ القيود الدورية
class RecurringEntryExecutions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recurringEntryId =>
      integer().references(RecurringEntries, #id)();
  TextColumn get glEntryId => text().references(GLEntries, #id)();
  DateTimeColumn get executionDate => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('posted'))(); // posted, failed, skipped
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
