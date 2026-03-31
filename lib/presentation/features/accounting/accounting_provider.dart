import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';

class AccountingProvider with ChangeNotifier {
  final AppDatabase db;
  late final AccountingService service;

  AccountingProvider(this.db) {
    service = AccountingService(db);
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
}
