import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:uuid/uuid.dart';

enum ClosingType { daily, monthly, yearly }

class ClosingValidation {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ClosingValidation({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}

class ClosingResult {
  final bool success;
  final String? error;
  final String message;
  final String? journalEntryId;
  final double? netIncome;

  ClosingResult({
    required this.success,
    this.error,
    required this.message,
    this.journalEntryId,
    this.netIncome,
  });
}

class FinancialClosingService {
  final AppDatabase db;
  late final AuditService _auditService;
  late final AccountingService _accountingService;

  FinancialClosingService(this.db) {
    _auditService = AuditService(db);
    _accountingService = AccountingService(db, EventBusService());
  }

  Future<ClosingValidation> validateBeforeMonthlyClosing(
    String periodId,
  ) async {
    final List<String> errors = [];
    final List<String> warnings = [];

    final period = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.id.equals(periodId))).getSingleOrNull();
    if (period == null) {
      errors.add('الفترة غير موجودة');
      return ClosingValidation(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    if (period.isClosed) {
      errors.add('الفترة مغلقة مسبقاً');
      return ClosingValidation(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    final draftSales = await (db.select(
      db.sales,
    )..where((s) => s.status.equals('DRAFT'))).get();
    if (draftSales.isNotEmpty) {
      warnings.add('يوجد ${draftSales.length} فاتورة مبيعات كمسودة');
    }

    final draftEntries = await (db.select(
      db.gLEntries,
    )..where((e) => e.status.equals('DRAFT'))).get();
    if (draftEntries.isNotEmpty) {
      errors.add('يوجد ${draftEntries.length} قيد محاسبي كمسودة');
    }

    return ClosingValidation(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  Future<ClosingResult> closeMonthlyPeriod({
    required String periodId,
    required String userId,
  }) async {
    final validation = await validateBeforeMonthlyClosing(periodId);
    if (!validation.isValid) {
      return ClosingResult(
        success: false,
        error: validation.errors.join(', '),
        message: '',
        journalEntryId: null,
      );
    }

    final period = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.id.equals(periodId))).getSingle();

    final incomeStatement = await _accountingService.getIncomeStatement(
      startDate: period.startDate,
      endDate: period.endDate,
    );

    await _createClosingEntry(
      netIncome: incomeStatement.netIncome,
      periodEndDate: period.endDate,
    );

    await (db.update(db.accountingPeriods)..where((p) => p.id.equals(periodId)))
        .write(const AccountingPeriodsCompanion(isClosed: Value(true)));

    await _auditService.logCreate(
      'AccountingPeriod',
      periodId,
      details: 'إقفال شهري - صافي الربح: ${incomeStatement.netIncome}',
    );

    return ClosingResult(
      success: true,
      error: null,
      message: 'تم إقفال الفترة بنجاح',
      journalEntryId: null,
      netIncome: incomeStatement.netIncome,
    );
  }

  Future<ClosingResult> closeYearlyPeriod({
    required String periodId,
    required String userId,
  }) async {
    final validation = await validateBeforeMonthlyClosing(periodId);
    if (!validation.isValid) {
      return ClosingResult(
        success: false,
        error: validation.errors.join(', '),
        message: '',
        journalEntryId: null,
      );
    }

    final period = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.id.equals(periodId))).getSingle();

    final incomeStatement = await _accountingService.getIncomeStatement(
      startDate: period.startDate,
      endDate: period.endDate,
    );

    await _createClosingEntry(
      netIncome: incomeStatement.netIncome,
      periodEndDate: period.endDate,
    );

    await (db.update(db.accountingPeriods)..where((p) => p.id.equals(periodId)))
        .write(const AccountingPeriodsCompanion(isClosed: Value(true)));

    await _auditService.logCreate(
      'AccountingPeriod',
      periodId,
      details: 'إقفال سنوي - صافي الربح: ${incomeStatement.netIncome}',
    );

    return ClosingResult(
      success: true,
      error: null,
      message: 'تم إقفال السنة المالية بنجاح',
      journalEntryId: null,
      netIncome: incomeStatement.netIncome,
    );
  }

  Future<String> _createClosingEntry({
    required double netIncome,
    required DateTime periodEndDate,
  }) async {
    if (netIncome == 0) return '';

    final entryId = const Uuid().v4();
    final retainedEarnings = await db.accountingDao.getAccountByCode('3010');

    if (retainedEarnings == null) return '';

    final revenues = await db.accountingDao.getAllAccounts();
    final revenueAccounts = revenues.where(
      (a) => a.type == 'REVENUE' && !a.isHeader,
    );
    final expenseAccounts = revenues.where(
      (a) => a.type == 'EXPENSE' && !a.isHeader,
    );

    final lines = <GLLinesCompanion>[];

    for (var acc in revenueAccounts) {
      final balance = await db.accountingDao.getAccountBalanceAsOfDate(
        acc.id,
        periodEndDate,
      );
      if (balance > 0) {
        lines.add(
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(balance),
            credit: const Value(0.0),
          ),
        );
      }
    }

    for (var acc in expenseAccounts) {
      final balance = await db.accountingDao.getAccountBalanceAsOfDate(
        acc.id,
        periodEndDate,
      );
      if (balance > 0) {
        lines.add(
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: const Value(0.0),
            credit: Value(balance),
          ),
        );
      }
    }

    if (netIncome > 0) {
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: retainedEarnings.id,
          debit: const Value(0.0),
          credit: Value(netIncome),
        ),
      );
    } else {
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: retainedEarnings.id,
          debit: Value(netIncome.abs()),
          credit: const Value(0.0),
        ),
      );
    }

    if (lines.isEmpty) return entryId;

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description:
          'إقفال período - ${periodEndDate.toLocal().toString().split(' ')[0]}',
      date: Value(periodEndDate),
      referenceType: const Value('PERIOD_CLOSING'),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
    );

    await db.accountingDao.createEntry(entry, lines);

    return entryId;
  }

  Future<ClosingResult> reopenPeriod(
    String periodId,
    String userId,
    String adminUserId,
  ) async {
    final period = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.id.equals(periodId))).getSingleOrNull();

    if (period == null) {
      return ClosingResult(
        success: false,
        error: 'الفترة غير موجود��',
        message: '',
        journalEntryId: null,
      );
    }

    if (!period.isClosed) {
      return ClosingResult(
        success: false,
        error: 'الفترة مفتوحة',
        message: '',
        journalEntryId: null,
      );
    }

    await (db.update(db.accountingPeriods)..where((p) => p.id.equals(periodId)))
        .write(const AccountingPeriodsCompanion(isClosed: Value(false)));

    await _auditService.logCreate(
      'AccountingPeriod',
      periodId,
      details: 'تم إعادة فتح الفترة المحاسبية',
    );

    return ClosingResult(
      success: true,
      error: null,
      message: 'تم إعادة فتح الفترة بنجاح',
      journalEntryId: null,
    );
  }

  Future<List<AccountingPeriod>> getOpenPeriods() async {
    return await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..orderBy([
            (p) =>
                OrderingTerm(expression: p.startDate, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<AccountingPeriod>> getClosedPeriods() async {
    return await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(true))
          ..orderBy([
            (p) =>
                OrderingTerm(expression: p.startDate, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<AccountingPeriod?> getCurrentPeriod() async {
    final now = DateTime.now();
    return await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..where((p) => p.startDate.isSmallerOrEqualValue(now))
          ..where((p) => p.endDate.isBiggerOrEqualValue(now)))
        .getSingleOrNull();
  }

  Future<ClosingResult> closeDailyShift({
    required String shiftId,
    required String userId,
    required double expectedCash,
    required double actualCash,
    String? note,
  }) async {
    final shift = await (db.select(
      db.shifts,
    )..where((s) => s.id.equals(shiftId))).getSingleOrNull();

    if (shift == null) {
      return ClosingResult(
        success: false,
        error: 'الوردية غير موجودة',
        message: '',
        journalEntryId: null,
      );
    }

    if (!shift.isOpen) {
      return ClosingResult(
        success: false,
        error: 'الوردية مغلقة مسبقاً',
        message: '',
        journalEntryId: null,
      );
    }

    final difference = actualCash - expectedCash;

    if (note != null || difference.abs() > 0.01) {
      await _recordShiftDifference(
        shiftId: shiftId,
        difference: difference,
        note: note ?? 'فرق نقدي',
        userId: userId,
      );
    }

    await (db.update(db.shifts)..where((s) => s.id.equals(shiftId))).write(
      ShiftsCompanion(
        isOpen: const Value(false),
        closingCash: Value(actualCash),
        expectedCash: Value(expectedCash),
        endTime: Value(DateTime.now()),
      ),
    );

    await _auditService.logCreate(
      'Shift',
      shiftId,
      details: 'إقفال وردية - الفرق: $difference',
    );

    return ClosingResult(
      success: true,
      error: null,
      message: 'تم إقفال الوردية بنجاح',
      journalEntryId: null,
    );
  }

  Future<void> _recordShiftDifference({
    required String shiftId,
    required double difference,
    required String note,
    required String userId,
  }) async {
    if (difference == 0) return;

    final cashAccount = await db.accountingDao.getAccountByCode('1010');
    final diffAccount = await db.accountingDao.getAccountByCode('5020');
    if (cashAccount == null || diffAccount == null) return;

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'فرق نقدي',
      date: Value(DateTime.now()),
      referenceType: const Value('SHIFT_DIFF'),
      status: const Value('POSTED'),
    );

    final lines = difference > 0
        ? [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: cashAccount.id,
              debit: Value(difference),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: diffAccount.id,
              credit: Value(difference),
            ),
          ]
        : [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: diffAccount.id,
              debit: Value(difference.abs()),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: cashAccount.id,
              credit: Value(difference.abs()),
            ),
          ];

    await db.accountingDao.createEntry(entry, lines);
  }

  Future<ClosingResult> createPeriod({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final existing = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.name.equals(name))).getSingleOrNull();
    if (existing != null) {
      return ClosingResult(
        success: false,
        error: 'توجد فترة بنفس الاسم',
        message: '',
        journalEntryId: null,
      );
    }

    final openPeriods = await getOpenPeriods();
    if (openPeriods.isNotEmpty) {
      return ClosingResult(
        success: false,
        error: 'توجد فترة مفتوحة: ${openPeriods.first.name}',
        message: '',
        journalEntryId: null,
      );
    }

    final periodId = const Uuid().v4();
    await db
        .into(db.accountingPeriods)
        .insert(
          AccountingPeriodsCompanion.insert(
            id: Value(periodId),
            name: name,
            startDate: startDate,
            endDate: endDate,
            isClosed: const Value(false),
            syncStatus: const Value(1),
          ),
        );

    await _auditService.logCreate(
      'AccountingPeriod',
      periodId,
      details: 'إنشاء فترة: $name',
    );

    return ClosingResult(
      success: true,
      error: null,
      message: 'تم إنشاء الفترة بنجاح',
      journalEntryId: periodId,
    );
  }
}
