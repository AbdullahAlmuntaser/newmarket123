import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class PayrollService {
  final AppDatabase db;

  PayrollService(this.db);

  // Use String payrollRunId (UUID) to match table changes
  Future<String> postPayrollJournalEntry(String payrollRunId) async {
    final payrollRun = await (db.select(db.hRPayrollRuns)
          ..where((t) => t.id.equals(payrollRunId)))
        .getSingle();

    final salaryExpenseAccountId = await _getSalaryExpenseAccount();
    final deductionsLiabilityAccountId = await _getDeductionsLiabilityAccount();
    final salariesPayableAccountId = await _getSalariesPayableAccount();

    final entryId = const Uuid().v4();

    await db.into(db.gLEntries).insert(
          GLEntriesCompanion.insert(
            id: Value(entryId),
            description: 'قيد رواتب فترة ${payrollRun.period}',
            date: Value(DateTime.now()),
            referenceType: const Value('PAYROLL'),
            referenceId: Value('PAY-${payrollRun.period}'),
            status: const Value('DRAFT'),
          ),
        );

    await db.batch((batch) {
      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: salaryExpenseAccountId,
            debit: Value(Decimal.parse(
                (payrollRun.totalSalaries + payrollRun.totalAllowances)
                    .toString())),
            credit: Value(Decimal.zero),
            memo: const Value('مصروف الرواتب والبدلات'),
          ));

      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: deductionsLiabilityAccountId,
            debit: Value(Decimal.zero),
            credit: Value(Decimal.parse(payrollRun.totalDeductions.toString())),
            memo: const Value('الخصومات المستحقة'),
          ));

      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: salariesPayableAccountId,
            debit: Value(Decimal.zero),
            credit: Value(Decimal.parse(payrollRun.netPayable.toString())),
            memo: const Value('رواتب مستحقة الدفع'),
          ));
    });

    await _postGLEntry(entryId);

    await (db.update(db.hRPayrollRuns)..where((t) => t.id.equals(payrollRunId)))
        .write(
      HRPayrollRunsCompanion(
        status: const Value('posted'),
        journalEntryId: Value(entryId),
      ),
    );

    return entryId;
  }

  Future<void> paySalaries(String payrollRunId) async {
    final payrollRun = await (db.select(db.hRPayrollRuns)
          ..where((t) => t.id.equals(payrollRunId)))
        .getSingle();

    if (payrollRun.status != 'posted') {
      throw Exception('يجب ترحيل قيد الرواتب أولاً');
    }

    final salariesPayableAccountId = await _getSalariesPayableAccount();
    final bankAccountId = await _getBankAccount();

    final paymentEntryId = const Uuid().v4();

    await db.into(db.gLEntries).insert(
          GLEntriesCompanion.insert(
            id: Value(paymentEntryId),
            description: 'سداد رواتب فترة ${payrollRun.period}',
            date: Value(DateTime.now()),
            referenceType: const Value('PAYROLL_PAYMENT'),
            referenceId: Value('PAY-PMT-${payrollRun.period}'),
            status: const Value('DRAFT'),
          ),
        );

    await db.batch((batch) {
      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: paymentEntryId,
            accountId: salariesPayableAccountId,
            debit: Value(Decimal.parse(payrollRun.netPayable.toString())),
            credit: Value(Decimal.zero),
            memo: const Value('سداد الرواتب المستحقة'),
          ));
      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: paymentEntryId,
            accountId: bankAccountId,
            debit: Value(Decimal.zero),
            credit: Value(Decimal.parse(payrollRun.netPayable.toString())),
            memo: const Value('خروج من البنك'),
          ));
    });

    await _postGLEntry(paymentEntryId);

    await (db.update(db.hRPayrollRuns)..where((t) => t.id.equals(payrollRunId)))
        .write(
      const HRPayrollRunsCompanion(status: Value('paid')),
    );

    final details = await (db.select(db.hRPayrollDetails)
          ..where((t) => t.payrollRunId.equals(payrollRunId)))
        .get();

    for (var detail in details) {
      await (db.update(db.hRPayrollDetails)
            ..where((t) => t.id.equals(detail.id)))
          .write(
        const HRPayrollDetailsCompanion(paymentStatus: Value('paid')),
      );
    }
  }

  Future<String> _getSalaryExpenseAccount() async {
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('60%')))
        .get();
    if (accounts.isEmpty) {
      throw Exception('لم يتم العثور على حساب مصروفات الرواتب');
    }
    return accounts.first.id;
  }

  Future<String> _getDeductionsLiabilityAccount() async {
    final accounts =
        await (db.select(db.gLAccounts)..where((t) => t.code.like('2%'))).get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب الخصوم');
    return accounts.first.id;
  }

  Future<String> _getSalariesPayableAccount() async {
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('21%')))
        .get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب المستحقات');
    return accounts.first.id;
  }

  Future<String> _getBankAccount() async {
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('10%')))
        .get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب البنك');
    return accounts.first.id;
  }

  Future<void> _postGLEntry(String entryId) async {
    await (db.update(db.gLEntries)..where((t) => t.id.equals(entryId))).write(
      GLEntriesCompanion(
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
      ),
    );
  }
}
