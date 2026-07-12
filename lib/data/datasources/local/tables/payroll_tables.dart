part of '../app_database.dart';

// جدول الموظفين
class HREmployees extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 2, max: 150)();
  TextColumn get code => text().withLength(min: 2, max: 50)();
  TextColumn get position => text().nullable()();
  TextColumn get department => text().nullable()();
  DateTimeColumn get hireDate => dateTime()();
  IntColumn get basicSalary => integer().map(const CentConverter())();
  IntColumn get housingAllowance =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get transportAllowance =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get otherAllowances =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get totalDeductions =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  TextColumn get bankAccountNumber => text().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('active'))();
  @override
  Set<Column> get primaryKey => {id};
}

// جدول الرواتب الشهرية
class HRPayrollRuns extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get period => text()();
  DateTimeColumn get runDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get totalSalaries =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get totalAllowances =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get totalDeductions =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get netPayable =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  TextColumn get journalEntryId => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('draft'))();
  TextColumn get notes => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

// جدول تفاصيل الرواتب لكل موظف
class HRPayrollDetails extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get payrollRunId => text().references(HRPayrollRuns, #id)();
  TextColumn get employeeId => text().references(HREmployees, #id)();
  IntColumn get basicSalary => integer().map(const CentConverter())();
  IntColumn get housingAllowance =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get transportAllowance =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get otherAllowances =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get grossSalary => integer().map(const CentConverter())();
  IntColumn get deductions =>
      integer().map(const CentConverter()).withDefault(const Constant(0))();
  IntColumn get netSalary => integer().map(const CentConverter())();
  TextColumn get paymentJournalEntryId => text().nullable()();
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('pending'))();
  @override
  Set<Column> get primaryKey => {id};
}

// جدول أنواع الخصومات الإضافية (سلف، غياب، إلخ)
class HRAdditionalDeductions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get employeeId => text().references(HREmployees, #id)();
  TextColumn get type => text()();
  IntColumn get amount => integer().map(const CentConverter())();
  DateTimeColumn get deductionDate => dateTime()();
  TextColumn get description => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  IntColumn get remainingInstallments =>
      integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}
