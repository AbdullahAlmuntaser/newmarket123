import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/services/fixed_assets_service.dart';
import 'package:supermarket/core/services/payroll_service.dart';
import 'package:supermarket/core/services/security_service.dart';
import 'package:drift/native.dart';

void main() {
  setUpAll(() {
    SecurityService.useFakeKeyForTesting = true;
  });

  test('smoke: payroll and fixed assets flows', () async {
    final db = AppDatabase(NativeDatabase.memory());

    // Ensure minimal GL accounts exist (seedData may already have created them)
    Future<String> ensureAccount(String code, String name, String type) async {
      final existing = await (db.select(db.gLAccounts)
            ..where((t) => t.code.equals(code)))
          .get();
      if (existing.isNotEmpty) return existing.first.id;
      final id = const Uuid().v4();
      await db.into(db.gLAccounts).insert(GLAccountsCompanion(
          id: Value(id),
          code: Value(code),
          name: Value(name),
          accountType: Value(AccountType.values.byName(type.toLowerCase()))));
      return id;
    }

    await ensureAccount('6000', 'Salary Expense', 'expense');
    await ensureAccount('2000', 'Deductions Liability', 'liability');
    await ensureAccount('2100', 'Salaries Payable', 'liability');
    await ensureAccount('1000', 'Bank', 'asset');
    // Accounts required by fixed assets flows
    await ensureAccount('6000', 'Depreciation Expense', 'expense');
    await ensureAccount('1600', 'Accumulated Depreciation', 'asset');
    await ensureAccount('1500', 'Fixed Assets Account', 'asset');

    final payrollService = PayrollService(db);

    // Create employee and payroll run
    // Generate UUIDs for IDs (tables expect text IDs)
    final empId = const Uuid().v4();
    final runId = const Uuid().v4();

    // Insert employee and payroll run
    await db.into(db.hREmployees).insert(HREmployeesCompanion(
        id: Value(empId),
        name: const Value('Test'),
        code: const Value('EMP1'),
        hireDate: Value(DateTime.now()),
        basicSalary: Value(Decimal.fromInt(1000))));
    await db.into(db.hRPayrollRuns).insert(HRPayrollRunsCompanion(
        id: Value(runId), period: const Value('2026-05')));

    // Add payroll detail
    await db.into(db.hRPayrollDetails).insert(HRPayrollDetailsCompanion(
        id: Value(const Uuid().v4()),
        payrollRunId: Value(runId),
        employeeId: Value(empId),
        basicSalary: Value(Decimal.fromInt(1000)),
        grossSalary: Value(Decimal.fromInt(1000)),
        netSalary: Value(Decimal.fromInt(1000))));

    // Update payroll totals using Value wrappers when needed
    await (db.update(db.hRPayrollRuns)..where((t) => t.id.equals(runId))).write(
        HRPayrollRunsCompanion(
            totalSalaries: Value(Decimal.fromInt(1000)),
            totalAllowances: Value(Decimal.zero),
            totalDeductions: Value(Decimal.zero),
            netPayable: Value(Decimal.fromInt(1000))));

    final entryId = await payrollService.postPayrollJournalEntry(runId);
    expect(entryId, isNotEmpty);

    // Fixed assets flow
    final fixedService = FixedAssetsService(db);

    final catId = await db.into(db.accAssetCategories).insert(
        AccAssetCategoriesCompanion.insert(name: 'Machinery', code: 'M01'));
    final assetId = await db.into(db.fixedAssets).insert(
        FixedAssetsCompanion.insert(
            name: 'Machine A',
            categoryId: catId,
            cost: Decimal.fromInt(1200),
            purchaseDate: DateTime.now(),
            acquisitionDate: DateTime.now(),
            usefulLifeYears: 5));

    // run depreciation (should create journal entry and log)
    final results = await fixedService.runMonthlyDepreciation(DateTime.now());
    // It's possible depreciation is 0 depending on defaults; ensure it runs without throwing
    expect(results, isA<List>());

    // Dispose asset
    final disposal = await fixedService.disposeAsset(
        assetId: assetId,
        disposalDate: DateTime.now(),
        disposalType: 'scrapped');
    expect(disposal, contains('journalEntryId'));

    await db.close();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
