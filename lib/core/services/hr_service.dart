import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:uuid/uuid.dart';

class HRService {
  final AppDatabase db;
  final PostingEngine postingEngine;
  late final AuditService _auditService;

  HRService(this.db, this.postingEngine) {
    _auditService = AuditService(db);
  }

  // Employee Management
  Future<List<Employee>> getAllEmployees() async {
    return await (db.select(
      db.employees,
    )..where((t) => t.isActive.equals(true))).get();
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
      await db
          .into(db.payrollEntries)
          .insert(
            PayrollEntriesCompanion.insert(
              id: Value(entryId),
              month: month,
              year: year,
              status: const Value('DRAFT'),
              note: Value(note),
            ),
          );

      for (var emp in employees) {
        await db
            .into(db.payrollLines)
            .insert(
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
      final entry = await (db.select(
        db.payrollEntries,
      )..where((t) => t.id.equals(entryId))).getSingle();
      if (entry.status != 'DRAFT') {
        throw Exception('كشف الرواتب معتمد بالفعل أو مدفوع');
      }

      final lines = await getPayrollLines(entryId);
      double totalNetSalary = lines.fold(0, (sum, line) => sum + line.netSalary);

      if (totalNetSalary <= 0) {
        throw Exception('لا يمكن اعتماد كشف رواتب بإجمالي صفر أو سالب');
      }

      await (db.update(db.payrollEntries)..where((t) => t.id.equals(entryId)))
          .write(const PayrollEntriesCompanion(status: Value('PAID')));

      await postingEngine.post(
        type: TransactionType.paymentOut, 
        referenceId: entryId,
        context: {
          'amount': totalNetSalary,
          'description': 'رواتب شهر ${entry.month}/${entry.year}',
        },
      );

      await _auditService.log(
        action: 'APPROVE_PAYROLL',
        targetEntity: 'PayrollEntries',
        entityId: entryId,
        userId: userId,
        details: 'Approved payroll for ${entry.month}/${entry.year}. Total: $totalNetSalary',
      );
    });
  }

  Future<List<PayrollEntry>> getAllPayrollEntries() async {
    return await (db.select(db.payrollEntries)..orderBy([
          (t) => OrderingTerm.desc(t.year),
          (t) => OrderingTerm.desc(t.month),
        ]))
        .get();
  }

  Future<List<PayrollLine>> getPayrollLines(String entryId) async {
    return await (db.select(
      db.payrollLines,
    )..where((t) => t.payrollEntryId.equals(entryId))).get();
  }
}
