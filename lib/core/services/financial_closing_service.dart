import 'package:drift/drift.dart';
import 'package:supermarket/core/constants/account_types.dart';
import 'package:supermarket/core/constants/app_enums.dart' hide AccountType;
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/financial_report_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
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
  final Decimal? netIncome;

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
  final FinancialReportService reportService;
  late final AuditService _auditService;

  FinancialClosingService(this.db, this.reportService) {
    _auditService = AuditService(db);
  }

  Future<ClosingValidation> validateBeforeMonthlyClosing(
    String periodId,
  ) async {
    final List<String> errors = [];
    final List<String> warnings = [];

    final period = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.id.equals(periodId)))
        .getSingleOrNull();
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
    )..where((s) => s.status.equals(DocumentStatus.draft.index)))
        .get();
    if (draftSales.isNotEmpty) {
      warnings.add('يوجد ${draftSales.length} فاتورة مبيعات كمسودة');
    }

    final draftEntries = await (db.select(
      db.gLEntries,
    )..where((e) => e.status.equals(DocumentStatus.draft.name.toUpperCase())))
        .get();
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
    )..where((p) => p.id.equals(periodId)))
        .getSingle();

    final incomeStatement = await reportService.getIncomeStatement(
      startDate: period.startDate,
      endDate: period.endDate,
    );

    await _createClosingEntry(
      netIncome: Decimal.parse(incomeStatement.netIncome.toString()),
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
    )..where((p) => p.id.equals(periodId)))
        .getSingle();

    final incomeStatement = await reportService.getIncomeStatement(
      startDate: period.startDate,
      endDate: period.endDate,
    );

    await _createClosingEntry(
      netIncome: Decimal.parse(incomeStatement.netIncome.toString()),
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
    required Decimal netIncome,
    required DateTime periodEndDate,
  }) async {
    if (netIncome == Decimal.zero) return '';

    final entryId = const Uuid().v4();
    final retainedEarnings = await db.accountingDao.getAccountByCode('3010');

    if (retainedEarnings == null) return '';

    final allAccounts = await db.accountingDao.getAllAccounts();
    final revenueAccounts = allAccounts.where(
      (a) => a.type == 'REVENUE' && !a.isHeader,
    );
    final expenseAccounts = allAccounts.where(
      (a) => a.type == 'EXPENSE' && !a.isHeader,
    );

    final lines = <GLLinesCompanion>[];

    for (var acc in revenueAccounts) {
      final Decimal rawBalance =
          await db.accountingDao.getAccountBalanceAsOfDate(
        acc.id,
        periodEndDate,
      );
      final Decimal balance = Decimal.parse(rawBalance.toString());
      if (balance > Decimal.zero) {
        lines.add(
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(balance),
            credit: Value(Decimal.zero),
          ),
        );
      }
    }

    for (var acc in expenseAccounts) {
      final Decimal rawBalance =
          await db.accountingDao.getAccountBalanceAsOfDate(
        acc.id,
        periodEndDate,
      );
      final Decimal balance = Decimal.parse(rawBalance.toString());
      if (balance > Decimal.zero) {
        lines.add(
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(Decimal.zero),
            credit: Value(balance),
          ),
        );
      }
    }

    if (netIncome > Decimal.zero) {
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: retainedEarnings.id,
          debit: Value(Decimal.zero),
          credit: Value(netIncome),
        ),
      );
    } else {
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: retainedEarnings.id,
          debit: Value(netIncome.abs()),
          credit: Value(Decimal.zero),
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

  Future<void> generateOpeningBalances({
    required int newFiscalYear,
    required String userId,
  }) async {
    final dao = db.accountingDao;
    final previousYear = newFiscalYear - 1;

    final prevYearPeriod = await (db.select(db.accountingPeriods)
          ..where((p) => p.fiscalYear.equals(previousYear))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.endDate, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();

    if (prevYearPeriod == null) {
      throw Exception(
          'Previous fiscal year $previousYear not found or not closed.');
    }

    final allAccounts = await dao.getAllAccounts();
    final balanceSheetAccounts = allAccounts.where((a) =>
        a.type == AccountType.asset ||
        a.type == AccountType.liability ||
        a.type == AccountType.equity);

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'أرصدة افتتاحية للسنة المالية $newFiscalYear',
      date: Value(DateTime(newFiscalYear, 1, 1)),
      referenceType: const Value('OPENING_BALANCE'),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(await _getDefaultBranchId()),
    );

    List<GLLinesCompanion> lines = [];

    for (var acc in balanceSheetAccounts) {
      final Decimal balance = Decimal.parse(
          (await dao.getAccountBalanceAsOfDate(acc.id, prevYearPeriod.endDate))
              .toString());

      if (balance == Decimal.zero) continue;

      if (acc.type == AccountType.asset) {
        if (balance > Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(balance),
            credit: Value(Decimal.zero),
            memo: const Value('Opening Balance'),
            branchId: Value(await _getDefaultBranchId()),
          ));
        } else if (balance < Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(Decimal.zero),
            credit: Value(balance.abs()),
            memo: const Value('Opening Balance'),
            branchId: Value(await _getDefaultBranchId()),
          ));
        }
      } else {
        if (balance > Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(Decimal.zero),
            credit: Value(balance),
            memo: const Value('Opening Balance'),
            branchId: Value(await _getDefaultBranchId()),
          ));
        } else if (balance < Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(balance.abs()),
            credit: Value(Decimal.zero),
            memo: const Value('Opening Balance'),
            branchId: Value(await _getDefaultBranchId()),
          ));
        }
      }
    }

    if (lines.isNotEmpty) {
      await dao.createEntry(entry, lines);
    }
  }

  Future<void> closeFinancialYear(DateTime date) async {
    final fiscalYear = date.year;

    await db.transaction(() async {
      await (db.update(db.accountingPeriods)
            ..where((p) => p.fiscalYear.equals(fiscalYear)))
          .write(const AccountingPeriodsCompanion(
              isClosed: Value(true), status: Value('CLOSED')));

      await generateOpeningBalances(
          newFiscalYear: fiscalYear + 1, userId: 'SYSTEM');
    });
  }

  Future<String> _getDefaultBranchId() async {
    final configService = AppConfigService(db);
    return await configService.getDefaultBranchId();
  }

  /// Creates an opening entry for a new period based on previous balances
  Future<String> createOpeningEntry({
    required String newPeriodId,
    required DateTime openingDate,
  }) async {
    final entryId = const Uuid().v4();
    final allAccounts = await db.accountingDao.getAllAccounts();

    // Asset, Liability, and Equity accounts need opening balances
    final permanentAccounts = allAccounts.where(
      (a) =>
          (a.type == 'ASSET' || a.type == 'LIABILITY' || a.type == 'EQUITY') &&
          !a.isHeader,
    );

    final lines = <GLLinesCompanion>[];
    for (var acc in permanentAccounts) {
      final Decimal rawBalance =
          await db.accountingDao.getAccountBalanceAsOfDate(
        acc.id,
        openingDate.subtract(const Duration(seconds: 1)),
      );
      final Decimal balance = Decimal.parse(rawBalance.toString());

      if (balance == Decimal.zero) continue;

      if (balance > Decimal.zero) {
        lines.add(
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(balance),
            credit: Value(Decimal.zero),
          ),
        );
      } else {
        lines.add(
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(Decimal.zero),
            credit: Value(balance.abs()),
          ),
        );
      }
    }

    if (lines.isEmpty) return '';

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'قيد افتتاحي - ${openingDate.year}',
      date: Value(openingDate),
      referenceType: const Value('OPENING_ENTRY'),
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
    )..where((p) => p.id.equals(periodId)))
        .getSingleOrNull();

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
          ..where((p) => p.startDate.isSmallerOrEqual(Variable(now)))
          ..where((p) => p.endDate.isBiggerOrEqual(Variable(now))))
        .getSingleOrNull();
  }

  Future<ClosingResult> closeDailyShift({
    required String shiftId,
    required String userId,
    required Decimal expectedCash,
    required Decimal actualCash,
    String? note,
  }) async {
    final shift = await (db.select(
      db.shifts,
    )..where((s) => s.id.equals(shiftId)))
        .getSingleOrNull();

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

    if (note != null || difference.abs() > Decimal.parse('0.01')) {
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
        closingCash: Value<Decimal?>(actualCash),
        expectedCash: Value<Decimal?>(expectedCash),
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
    required Decimal difference,
    required String note,
    required String userId,
  }) async {
    if (difference == Decimal.zero) return;

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

    final lines = difference > Decimal.zero
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
    )..where((p) => p.name.equals(name)))
        .getSingleOrNull();
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
    await db.into(db.accountingPeriods).insert(
          AccountingPeriodsCompanion.insert(
            id: Value(periodId),
            name: name,
            fiscalYear: startDate.year,
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
