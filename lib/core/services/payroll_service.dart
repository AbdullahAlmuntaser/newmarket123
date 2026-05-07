import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class PayrollService {
  final AppDatabase db;

  PayrollService(this.db);

  Future<int> postPayrollJournalEntry(int payrollRunId) async {
    final payrollRun = await (db.select(db.hRPayrollRuns)
        ..where((t) => t.id.equals(payrollRunId)))
        .getSingle();

    final salaryExpenseAccountId = await _getSalaryExpenseAccount();
    final deductionsLiabilityAccountId = await _getDeductionsLiabilityAccount();
    final salariesPayableAccountId = await _getSalariesPayableAccount();

    final entryId = await db.into(db.gLEntries).insert(
      GLEntriesCompanion.insert(
        description: 'قيد رواتب فترة ${payrollRun.period}',
        date: Value(DateTime.now()),
        referenceType: const Value('PAYROLL'),
        referenceId: Value('PAY-${payrollRun.period}'),
        status: const Value('DRAFT'),
      ),
    );

    await db.batch((batch) {
      batch.insert(db.gLLines, GLLinesCompanion.insert(
        entryId: entryId.toString(),
        accountId: salaryExpenseAccountId,
        debit: Value(payrollRun.totalSalaries + payrollRun.totalAllowances),
        credit: const Value(0.0),
        memo: const Value('مصروف الرواتب والبدلات'),
      ));

      batch.insert(db.gLLines, GLLinesCompanion.insert(
        entryId: entryId.toString(),
        accountId: deductionsLiabilityAccountId,
        debit: const Value(0.0),
        credit: Value(payrollRun.totalDeductions),
        memo: const Value('الخصومات المستحقة'),
      ));

      batch.insert(db.gLLines, GLLinesCompanion.insert(
        entryId: entryId.toString(),
        accountId: salariesPayableAccountId,
        debit: const Value(0.0),
        credit: Value(payrollRun.netPayable),
        memo: const Value('رواتب مستحقة الدفع'),
      ));
    });

    await _postGLEntry(entryId);

    await (db.update(db.hRPayrollRuns)..where((t) => t.id.equals(payrollRunId))).write(
      HRPayrollRunsCompanion(
        status: const Value('posted'),
        journalEntryId: Value(entryId),
      ),
    );

    return entryId;
  }

  Future<void> paySalaries(int payrollRunId) async {
    final payrollRun = await (db.select(db.hRPayrollRuns)
        ..where((t) => t.id.equals(payrollRunId)))
        .getSingle();

    if (payrollRun.status != 'posted') {
      throw Exception('يجب ترحيل قيد الرواتب أولاً');
    }

    final salariesPayableAccountId = await _getSalariesPayableAccount();
    final bankAccountId = await _getBankAccount();

    final paymentEntryId = await db.into(db.gLEntries).insert(
      GLEntriesCompanion.insert(
        description: 'سداد رواتب فترة ${payrollRun.period}',
        date: Value(DateTime.now()),
        referenceType: const Value('PAYROLL_PAYMENT'),
        referenceId: Value('PAY-PMT-${payrollRun.period}'),
        status: const Value('DRAFT'),
      ),
    );

    await db.batch((batch) {
      batch.insert(db.gLLines, GLLinesCompanion.insert(
        entryId: paymentEntryId.toString(),
        accountId: salariesPayableAccountId,
        debit: Value(payrollRun.netPayable),
        credit: const Value(0.0),
        memo: const Value('سداد الرواتب المستحقة'),
      ));
      batch.insert(db.gLLines, GLLinesCompanion.insert(
        entryId: paymentEntryId.toString(),
        accountId: bankAccountId,
        debit: const Value(0.0),
        credit: Value(payrollRun.netPayable),
        memo: const Value('خروج من البنك'),
      ));
    });

    await _postGLEntry(paymentEntryId);

    await (db.update(db.hRPayrollRuns)..where((t) => t.id.equals(payrollRunId))).write(
      const HRPayrollRunsCompanion(status: Value('paid')),
    );

    final details = await (db.select(db.hRPayrollDetails)
        ..where((t) => t.payrollRunId.equals(payrollRunId)))
        .get();

    for (var detail in details) {
      await (db.update(db.hRPayrollDetails)..where((t) => t.id.equals(detail.id))).write(
        const HRPayrollDetailsCompanion(paymentStatus: Value('paid')),
      );
    }
  }

  Future<String> _getSalaryExpenseAccount() async {
    final accounts = await (db.select(db.gLAccounts)
        ..where((t) => t.code.like('60%')))
        .get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب مصروفات الرواتب');
    return accounts.first.id;
  }

  Future<String> _getDeductionsLiabilityAccount() async {
    final accounts = await (db.select(db.gLAccounts)
        ..where((t) => t.code.like('2%')))
        .get();
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

  Future<void> _postGLEntry(int entryId) async {
    await (db.update(db.gLEntries)..where((t) => t.id.equals(entryId.toString()))).write(
      GLEntriesCompanion(
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
      ),
    );
  }
}
