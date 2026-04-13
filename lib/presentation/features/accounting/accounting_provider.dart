import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:supermarket/injection_container.dart';
import 'package:uuid/uuid.dart';

class AccountingProvider with ChangeNotifier {
  final AppDatabase db;
  late final AccountingService service;

  AccountingProvider(this.db) {
    service = AccountingService(db, sl<EventBusService>());
  }

  void refresh() {
    notifyListeners();
  }

  // Dashboard
  Future<AccountingDashboardData> getDashboardData() {
    return service.getDashboardData();
  }

  // Accounts
  Stream<List<GLAccount>> watchAccounts() {
    return db.accountingDao.watchAccounts();
  }

  Future<void> seedAccounts() async {
    await service.seedDefaultAccounts();
    notifyListeners();
  }

  Future<void> addAccount({
    required String code,
    required String name,
    required String type,
    bool isHeader = false,
  }) async {
    await db.accountingDao.createAccount(
      GLAccountsCompanion.insert(
        code: code,
        name: name,
        type: type,
        isHeader: Value(isHeader),
      ),
    );
    notifyListeners();
  }

  // Entries
  Stream<List<GLEntry>> watchEntries() {
    return db.accountingDao.watchRecentEntries();
  }

  Future<List<GLLineWithAccount>> getEntryLines(String entryId) {
    return db.accountingDao.getLinesForEntry(entryId);
  }

  Future<void> closeYear(DateTime date) async {
    await service.closeFinancialYear(date);
    notifyListeners();
  }

  // Reports
  Future<List<TrialBalanceItem>> getTrialBalance() {
    return db.accountingDao.getTrialBalance();
  }

  Future<CashFlowData> getCashFlow({DateTime? startDate, DateTime? endDate}) {
    return service.getCashFlowStatement(startDate: startDate, endDate: endDate);
  }

  Future<IncomeStatementData> getIncomeStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return service.getIncomeStatement(startDate: startDate, endDate: endDate);
  }

  Future<BalanceSheetData> getBalanceSheet({DateTime? date}) {
    return service.getBalanceSheet(date: date);
  }

  Future<VatReportData> getVatReport({DateTime? startDate, DateTime? endDate}) {
    return service.getVatReport(startDate: startDate, endDate: endDate);
  }

  Future<void> createManualEntry({
    required String description,
    required DateTime date,
    required List<GLLinesCompanion> lines,
  }) async {
    // Basic validation for balanced entry
    double totalDebit = 0;
    double totalCredit = 0;
    for (var line in lines) {
      totalDebit += line.debit.value;
      totalCredit += line.credit.value;
    }

    if ((totalDebit - totalCredit).abs() > 0.001) {
      throw Exception(
        'القيد غير متوازن. المدين: $totalDebit, الدائن: $totalCredit',
      );
    }

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: description,
      date: Value(date),
      referenceType: const Value('MANUAL'),
    );

    // Update lines with entryId
    final updatedLines = lines
        .map((l) => l.copyWith(entryId: Value(entryId)))
        .toList();

    await db.accountingDao.createEntry(entry, updatedLines);
    notifyListeners();
  }

  // Cost Centers
  Stream<List<CostCenter>> watchCostCenters() {
    return db.accountingDao.watchCostCenters();
  }

  Future<void> addCostCenter({
    required String code,
    required String name,
    bool isActive = true,
  }) async {
    await db.accountingDao.createCostCenter(
      CostCentersCompanion.insert(
        code: code,
        name: name,
        isActive: Value(isActive),
      ),
    );
    notifyListeners();
  }

  Future<void> toggleCostCenterStatus(CostCenter cc) async {
    await db.accountingDao.updateCostCenter(
      cc.copyWith(isActive: !cc.isActive),
    );
    notifyListeners();
  }
}
