import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

class HRService {
  final AppDatabase db;
  late final AuditService _auditService;

  HRService(this.db) {
    _auditService = AuditService(db);
  }

  // Employee Management
  Future<List<Employee>> getAllEmployees() async {
    return await (db.select(db.employees)..where((t) => t.isActive.equals(true))).get();
  }

  Future<void> addEmployee(EmployeesCompanion employee) async {
    await db.into(db.employees).insert(employee);
  }

  Future<void> updateEmployee(Employee employee) async {
    await db.update(db.employees).replace(employee);
  }

  Future<void> deleteEmployee(String id) async {
    await (db.update(db.employees)..where((t) => t.id.equals(id))).write(
      const EmployeesCompanion(isActive: Value(false)),
    );
  }

  // Payroll Management
  Future<void> generatePayroll(int month, int year, {String? note}) async {
    final employees = await getAllEmployees();
    final entryId = const Uuid().v4();

    await db.transaction(() async {
      await db.into(db.payrollEntries).insert(
            PayrollEntriesCompanion.insert(
              id: Value(entryId),
              month: month,
              year: year,
              status: const Value('DRAFT'),
              note: Value(note),
            ),
          );

      for (var emp in employees) {
        await db.into(db.payrollLines).insert(
              PayrollLinesCompanion.insert(
                id: Value(const Uuid().v4()),
                payrollEntryId: entryId,
                employeeId: emp.id,
                basicSalary: emp.basicSalary,
                allowances: const Value(0.0),
                deductions: const Value(0.0),
                netSalary: emp.basicSalary,
              ),
            );
      }
    });
  }

  /// اعتماد كشف الرواتب وتسجيله محاسبياً
  Future<void> approveAndPostPayroll(String entryId, {String? userId}) async {
    await db.transaction(() async {
      // 1. جلب الكشف والتأكد من حالته
      final entry = await (db.select(db.payrollEntries)..where((t) => t.id.equals(entryId))).getSingle();
      if (entry.status != 'DRAFT') {
        throw Exception('كشف الرواتب معتمد بالفعل أو مدفوع');
      }

      // 2. جلب التفاصيل لحساب الإجمالي
      final lines = await getPayrollLines(entryId);
      double totalNetSalary = lines.fold(0, (sum, line) => sum + line.netSalary);

      if (totalNetSalary <= 0) {
        throw Exception('لا يمكن اعتماد كشف رواتب بإجمالي صفر أو سالب');
      }

      // 3. تحديث حالة الكشف
      await (db.update(db.payrollEntries)..where((t) => t.id.equals(entryId))).write(
        const PayrollEntriesCompanion(status: Value('PAID')),
      );

      // 4. إنشاء القيد المحاسبي
      await _postPayrollToAccounting(totalNetSalary, entry);

      // 5. توثيق العملية
      await _auditService.log(
        action: 'APPROVE_PAYROLL',
        targetEntity: 'PayrollEntries',
        entityId: entryId,
        userId: userId,
        details: 'Approved payroll for ${entry.month}/${entry.year}. Total: $totalNetSalary',
      );
    });
  }

  Future<void> _postPayrollToAccounting(double amount, PayrollEntry entry) async {
    final dao = db.accountingDao;
    final journalEntryId = const Uuid().v4();

    // نحتاج لحساب المصاريف (الرواتب) وحساب النقدية
    final expenseAccount = await dao.getAccountByCode(AccountingService.codeOperatingExpenses);
    final cashAccount = await dao.getAccountByCode(AccountingService.codeCash);

    if (expenseAccount == null || cashAccount == null) {
      throw Exception('Missing GL accounts for payroll posting (Salaries Expense or Cash).');
    }

    final journalEntry = GLEntriesCompanion.insert(
      id: Value(journalEntryId),
      description: 'رواتب شهر ${entry.month}/${entry.year}',
      date: Value(DateTime.now()),
      referenceType: const Value('PAYROLL'),
      referenceId: Value(entry.id),
    );

    final lines = [
      // مدين: مصاريف الرواتب
      GLLinesCompanion.insert(
        entryId: journalEntryId,
        accountId: expenseAccount.id,
        debit: Value(amount),
        credit: const Value(0.0),
        memo: Value('إجمالي رواتب شهر ${entry.month}/${entry.year}'),
      ),
      // دائن: النقدية
      GLLinesCompanion.insert(
        entryId: journalEntryId,
        accountId: cashAccount.id,
        debit: const Value(0.0),
        credit: Value(amount),
        memo: Value('صرف رواتب شهر ${entry.month}/${entry.year}'),
      ),
    ];

    await dao.createEntry(journalEntry, lines);
  }

  Future<List<PayrollEntry>> getAllPayrollEntries() async {
    return await (db.select(db.payrollEntries)..orderBy([(t) => OrderingTerm.desc(t.year), (t) => OrderingTerm.desc(t.month)])).get();
  }

  Future<List<PayrollLine>> getPayrollLines(String entryId) async {
    return await (db.select(db.payrollLines)..where((t) => t.payrollEntryId.equals(entryId))).get();
  }
}
