import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class HRService {
  final AppDatabase db;

  HRService(this.db);

  Future<void> recordAdvance({
    required String employeeId,
    required double amount,
    String? note,
  }) async {
    await db.transaction(() async {
      // 1. Record in Additional Deductions
      await db.into(db.hRAdditionalDeductions).insert(
        HRAdditionalDeductionsCompanion.insert(
          employeeId: employeeId,
          type: 'advance',
          amount: amount,
          deductionDate: DateTime.now(),
          description: Value(note),
        ),
      );

      // 2. Create Accounting Entry (Credit Cash, Debit Employee Advance Account)
      // Assuming 1030 is for all receivables, but normally we'd have a specific advance account.
      // For simplicity, we use a general expense or receivable.
      final entryId = const Uuid().v4();
      final cashAccount = await db.accountingDao.getAccountByCode('1010');
      final advanceAccount = await db.accountingDao.getAccountByCode('1030'); // Simplified

      if (cashAccount != null && advanceAccount != null) {
        final entry = GLEntriesCompanion.insert(
          id: Value(entryId),
          description: 'سلفة موظف: $note',
          date: Value(DateTime.now()),
          referenceType: const Value('HR_ADVANCE'),
          referenceId: Value(employeeId),
          status: const Value('POSTED'),
          postedAt: Value(DateTime.now()),
        );

        final lines = [
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: advanceAccount.id,
            debit: Value(amount),
            credit: const Value(0.0),
          ),
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: cashAccount.id,
            debit: const Value(0.0),
            credit: Value(amount),
          ),
        ];

        await db.accountingDao.createEntry(entry, lines);
      }
    });
  }

  Future<void> calculateMonthlyPayroll(String period) async {
    // Basic logic: base salary + allowances - deductions
    await db.transaction(() async {
      final employees = await (db.select(db.hREmployees)..where((t) => t.status.equals('active'))).get();
      
      double totalSalaries = 0;
      double totalAllowances = 0;
      double totalDeductions = 0;

      final runId = await db.into(db.hRPayrollRuns).insert(
        HRPayrollRunsCompanion.insert(
          period: period,
          status: const Value('draft'),
        ),
      );

      for (var emp in employees) {
        // Get advances for this month
        final additions = await (db.select(db.hRAdditionalDeductions)
          ..where((t) => t.employeeId.equals(emp.id))).get();
        
        double monthlyDeductions = additions.fold(0, (sum, item) => sum + item.amount);

        final gross = emp.basicSalary + emp.housingAllowance + emp.transportAllowance + emp.otherAllowances;
        final net = gross - monthlyDeductions;

        await db.into(db.hRPayrollDetails).insert(
          HRPayrollDetailsCompanion.insert(
            payrollRunId: runId,
            employeeId: emp.id,
            basicSalary: emp.basicSalary,
            housingAllowance: Value(emp.housingAllowance),
            transportAllowance: Value(emp.transportAllowance),
            otherAllowances: Value(emp.otherAllowances),
            grossSalary: gross,
            deductions: Value(monthlyDeductions),
            netSalary: net,
          ),
        );

        totalSalaries += emp.basicSalary;
        totalAllowances += (emp.housingAllowance + emp.transportAllowance + emp.otherAllowances);
        totalDeductions += monthlyDeductions;
      }

      await (db.update(db.hRPayrollRuns)..where((t) => t.id.equals(runId))).write(
        HRPayrollRunsCompanion(
          totalSalaries: Value(totalSalaries),
          totalAllowances: Value(totalAllowances),
          totalDeductions: Value(totalDeductions),
          netPayable: Value(totalSalaries + totalAllowances - totalDeductions),
        ),
      );
    });
  }

  Future<List<HREmployee>> getAllEmployees() async {
    return await db.select(db.hREmployees).get();
  }

  Future<void> addEmployee(HREmployeesCompanion employee) async {
    await db.into(db.hREmployees).insert(employee);
  }

  Future<void> updateEmployee(HREmployee employee) async {
    await db.update(db.hREmployees).replace(employee);
  }

  Future<void> deleteEmployee(String id) async {
    await (db.delete(db.hREmployees)..where((t) => t.id.equals(id))).go();
  }

  Future<List<HRPayrollRun>> getAllPayrollEntries() async {
    return await db.select(db.hRPayrollRuns).get();
  }

  Future<void> generatePayroll(String period) async {
    await calculateMonthlyPayroll(period);
  }

  Future<void> generatePayrollWithDetails(int month, int year, {String? note}) async {
    final period = '$year-${month.toString().padLeft(2, '0')}';
    await calculateMonthlyPayroll(period);
  }

  Future<List<HRPayrollDetail>> getPayrollLines(String runId) async {
    return await (db.select(db.hRPayrollDetails)
          ..where((t) => t.payrollRunId.equals(runId)))
        .get();
  }
}
