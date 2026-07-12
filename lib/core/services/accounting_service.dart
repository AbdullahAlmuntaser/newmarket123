import 'package:supermarket/core/constants/account_codes.dart';
import 'package:supermarket/core/models/accounting/accounting_dashboard_data.dart';
import 'package:supermarket/core/models/accounting/balance_sheet_data.dart';
import 'package:supermarket/core/models/accounting/cash_flow_data.dart';
import 'package:supermarket/core/models/accounting/financial_ratios_data.dart';
import 'package:supermarket/core/models/accounting/income_statement_data.dart';
import 'package:supermarket/core/models/accounting/vat_report_data.dart';
import 'package:supermarket/core/services/chart_of_accounts_service.dart';
import 'package:supermarket/core/services/depreciation_service.dart';
import 'package:supermarket/core/services/financial_closing_service.dart';
import 'package:supermarket/core/services/financial_report_service.dart';
import 'package:supermarket/core/services/journal_service.dart';
import 'package:supermarket/core/services/vat_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;

class AccountingService {
  static const String codeCash = AccountCodes.cash;
  static const String codeBank = AccountCodes.bank;
  static const String codeAccountsReceivable = AccountCodes.accountsReceivable;
  static const String codeInventory = AccountCodes.inventory;
  static const String codeInputVAT = AccountCodes.inputVAT;
  static const String codeFixedAssets = AccountCodes.fixedAssets;
  static const String codeAccumulatedDepreciation =
      AccountCodes.accumulatedDepreciation;
  static const String codeAccountsPayable = AccountCodes.accountsPayable;
  static const String codeOutputVAT = AccountCodes.outputVAT;
  static const String codeLoansPayable = AccountCodes.loansPayable;
  static const String codeCapital = AccountCodes.capital;
  static const String codeRetainedEarnings = AccountCodes.retainedEarnings;
  static const String codeSalesRevenue = AccountCodes.salesRevenue;
  static const String codeSalesReturns = AccountCodes.salesReturns;
  static const String codeCOGS = AccountCodes.cogs;
  static const String codePurchaseReturns = AccountCodes.purchaseReturns;
  static const String codeCashOverShort = AccountCodes.cashOverShort;
  static const String codeOperatingExpenses = AccountCodes.operatingExpenses;
  static const String codeDepreciationExpense =
      AccountCodes.depreciationExpense;

  final AppDatabase db;
  late final ChartOfAccountsService _chartOfAccounts;
  late final FinancialReportService _reports;
  late final VatService _vat;
  late final DepreciationService _depreciation;
  late final JournalService _journal;

  AccountingService(this.db, [Object? eventBus])
      : _chartOfAccounts = ChartOfAccountsService(db),
        _reports = FinancialReportService(db),
        _vat = VatService(db),
        _depreciation = DepreciationService(db),
        _journal = JournalService(db);

  Future<void> dispose() async {}

  Future<void> seedDefaultAccounts({String? branchId}) =>
      _chartOfAccounts.seedDefaultAccounts(branchId: branchId);

  Future<FinancialRatiosData> getFinancialRatios() =>
      _reports.getFinancialRatios();

  Future<AccountingDashboardData> getDashboardData() =>
      _reports.getDashboardData();

  Future<String> createCustomerAccount(String customerName) =>
      _chartOfAccounts.createCustomerAccount(customerName);

  Future<String> createSupplierAccount(String supplierName) =>
      _chartOfAccounts.createSupplierAccount(supplierName);

  Future<void> runAutomaticDepreciation(DateTime asOfDate) =>
      _depreciation.runAutomaticDepreciation(asOfDate);

  Future<VatReportData> getVatReport({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _vat.getVatReport(startDate: startDate, endDate: endDate);

  Future<void> generateOpeningBalances({
    required int newFiscalYear,
    required String userId,
  }) =>
      di.sl<FinancialClosingService>().generateOpeningBalances(
            newFiscalYear: newFiscalYear,
            userId: userId,
          );

  Future<IncomeStatementData> getIncomeStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _reports.getIncomeStatement(startDate: startDate, endDate: endDate);

  Future<Map<String, IncomeStatementData>> compareIncomeStatement({
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
  }) =>
      _reports.compareIncomeStatement(
        period1Start: period1Start,
        period1End: period1End,
        period2Start: period2Start,
        period2End: period2End,
      );

  Future<BalanceSheetData> getBalanceSheet({DateTime? date}) =>
      _reports.getBalanceSheet(date: date);

  Future<void> createRevaluationEntry(
    dynamic invoice,
    String reason, {
    String? debitAccountId,
    String? creditAccountId,
    Decimal? amount,
  }) =>
      _journal.createRevaluationEntry(
        invoice,
        reason,
        debitAccountId: debitAccountId,
        creditAccountId: creditAccountId,
        amount: amount,
      );

  Future<void> closeFinancialYear(DateTime date) =>
      di.sl<FinancialClosingService>().closeFinancialYear(date);

  Future<void> recordExpense({
    required String description,
    required Decimal amount,
    required DateTime date,
    required String expenseAccountId,
    required String paymentAccountId,
    String? costCenterId,
  }) =>
      _journal.recordExpense(
        description: description,
        amount: amount,
        date: date,
        expenseAccountId: expenseAccountId,
        paymentAccountId: paymentAccountId,
        costCenterId: costCenterId,
      );

  Future<CashFlowData> getCashFlowStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _reports.getCashFlowStatement(startDate: startDate, endDate: endDate);
}
