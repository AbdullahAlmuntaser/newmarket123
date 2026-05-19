import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// جدول الموظفين
class HREmployees extends Table {
  // Use UUID text IDs for consistency with the rest of the system
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 2, max: 150)();
  TextColumn get code => text().withLength(min: 2, max: 50)();
  TextColumn get position => text().nullable()();
  TextColumn get department => text().nullable()();
  DateTimeColumn get hireDate => dateTime()();
  RealColumn get basicSalary => real()();
  RealColumn get housingAllowance => real().withDefault(const Constant(0.0))();
  RealColumn get transportAllowance =>
      real().withDefault(const Constant(0.0))();
  RealColumn get otherAllowances => real().withDefault(const Constant(0.0))();
  RealColumn get totalDeductions =>
      real().withDefault(const Constant(0.0))(); // خصومات ثابتة
  TextColumn get bankAccountNumber => text().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active, terminated
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول الرواتب الشهرية
class HRPayrollRuns extends Table {
  // Use UUID text IDs to match GLEntries and other syncable tables
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get period => text()(); // مثال: "2024-01"
  DateTimeColumn get runDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalSalaries => real().withDefault(const Constant(0.0))();
  RealColumn get totalAllowances => real().withDefault(const Constant(0.0))();
  RealColumn get totalDeductions => real().withDefault(const Constant(0.0))();
  RealColumn get netPayable => real().withDefault(const Constant(0.0))();
  // journalEntryId links to gl_entries.id (UUID string)
  TextColumn get journalEntryId => text().nullable()(); // ربط بالقيد المحاسبي
  TextColumn get status =>
      text().withDefault(const Constant('draft'))(); // draft, posted, paid
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول تفاصيل الرواتب لكل موظف
class HRPayrollDetails extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get payrollRunId => text().references(HRPayrollRuns, #id)();
  TextColumn get employeeId => text().references(HREmployees, #id)();
  RealColumn get basicSalary => real()();
  RealColumn get housingAllowance => real().withDefault(const Constant(0.0))();
  RealColumn get transportAllowance =>
      real().withDefault(const Constant(0.0))();
  RealColumn get otherAllowances => real().withDefault(const Constant(0.0))();
  RealColumn get grossSalary => real()(); // إجمالي الراتب قبل الخصومات
  RealColumn get deductions =>
      real().withDefault(const Constant(0.0))(); // صافي الخصومات لهذا الشهر
  RealColumn get netSalary => real()(); // صافي الراتب
  TextColumn get paymentJournalEntryId =>
      text().nullable()(); // قيد السداد الفردي (اختياري)
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('pending'))(); // pending, paid
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول أنواع الخصومات الإضافية (سلف، غياب، إلخ)
class HRAdditionalDeductions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get employeeId => text().references(HREmployees, #id)();
  TextColumn get type => text()(); // loan, absence, advance
  RealColumn get amount => real()();
  DateTimeColumn get deductionDate => dateTime()();
  TextColumn get description => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  IntColumn get remainingInstallments =>
      integer().withDefault(const Constant(0))(); // للأقساط
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
