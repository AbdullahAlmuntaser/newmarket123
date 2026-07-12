import 'package:drift/drift.dart';
import 'package:supermarket/core/constants/account_codes.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/core/models/accounting/account_tree_node.dart';
import 'package:supermarket/core/models/accounting/accounting_dashboard_data.dart';
import 'package:supermarket/core/models/accounting/balance_sheet_data.dart';
import 'package:supermarket/core/models/accounting/balance_sheet_item.dart';
import 'package:supermarket/core/models/accounting/cash_flow_data.dart';
import 'package:supermarket/core/models/accounting/daily_value.dart';
import 'package:supermarket/core/models/accounting/dashboard_top_product.dart';
import 'package:supermarket/core/models/accounting/financial_ratios_data.dart';
import 'package:supermarket/core/models/accounting/income_statement_data.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';

class FinancialReportService {
  final AppDatabase db;

  FinancialReportService(this.db);

  Future<IncomeStatementData> getIncomeStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dao = db.accountingDao;
    final end = endDate ?? DateTime.now();

    final List<TrialBalanceItem> allItems;
    if (startDate != null) {
      final balances = await dao.getAllAccountBalancesInRange(startDate, end);
      allItems = balances.map((b) {
        if (b.account.type == 'REVENUE') {
          return TrialBalanceItem(b.account, Decimal.zero, b.netBalance);
        } else {
          return TrialBalanceItem(b.account, b.netBalance, Decimal.zero);
        }
      }).toList();
    } else {
      final balances = await dao.getAllAccountBalancesAsOfDate(end);
      allItems = balances.map((b) {
        if (b.account.type == 'REVENUE') {
          return TrialBalanceItem(b.account, Decimal.zero, b.netBalance);
        } else {
          return TrialBalanceItem(b.account, b.netBalance, Decimal.zero);
        }
      }).toList();
    }

    final revenues =
        allItems.where((i) => i.account.type == 'REVENUE').toList();
    final expenses =
        allItems.where((i) => i.account.type == 'EXPENSE').toList();

    final Decimal totalRevenue =
        revenues.fold(Decimal.zero, (sum, item) => sum + item.totalCredit);
    final Decimal totalExpense =
        expenses.fold(Decimal.zero, (sum, item) => sum + item.totalDebit);

    return IncomeStatementData(
      revenues: revenues,
      expenses: expenses,
      totalRevenue: totalRevenue,
      totalExpense: totalExpense,
      netIncome: totalRevenue - totalExpense,
      startDate: startDate,
      endDate: end,
    );
  }

  Future<Map<String, IncomeStatementData>> compareIncomeStatement({
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
  }) async {
    final data1 =
        await getIncomeStatement(startDate: period1Start, endDate: period1End);
    final data2 =
        await getIncomeStatement(startDate: period2Start, endDate: period2End);
    return {
      'period1': data1,
      'period2': data2,
    };
  }

  Future<BalanceSheetData> getBalanceSheet({DateTime? date}) async {
    final dao = db.accountingDao;
    final asOfDate = date ?? DateTime.now();
    final tree = await dao.getAccountTree(asOfDate: asOfDate);

    final List<BalanceSheetItem> assets = [];
    final List<BalanceSheetItem> liabilities = [];
    final List<BalanceSheetItem> equity = [];

    for (final node in _flattenTree(tree)) {
      final balance = node.treeBalance;
      if (balance == Decimal.zero) continue;
      if (node.account.type == 'ASSET') {
        assets.add(BalanceSheetItem(node.account, balance));
      } else if (node.account.type == 'LIABILITY') {
        liabilities.add(BalanceSheetItem(node.account, balance));
      } else if (node.account.type == 'EQUITY') {
        equity.add(BalanceSheetItem(node.account, balance));
      }
    }

    Decimal totalAssets =
        assets.fold(Decimal.zero, (sum, item) => sum + item.balance);
    Decimal totalLiabilities =
        liabilities.fold(Decimal.zero, (sum, item) => sum + item.balance);
    Decimal totalEquity =
        equity.fold(Decimal.zero, (sum, item) => sum + item.balance);

    final incomeStatement = await getIncomeStatement(endDate: asOfDate);
    totalEquity += incomeStatement.netIncome;

    return BalanceSheetData(
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      totalEquity: totalEquity,
      netIncome: incomeStatement.netIncome,
      date: asOfDate,
    );
  }

  List<AccountTreeNode> _flattenTree(List<AccountTreeNode> nodes) {
    final result = <AccountTreeNode>[];
    for (final node in nodes) {
      result.add(node);
      result.addAll(_flattenTree(node.children));
    }
    return result;
  }

  Future<CashFlowData> getCashFlowStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dao = db.accountingDao;
    final reportStartDate = startDate ?? DateTime(2000);
    final reportEndDate = endDate ?? DateTime.now();
    final glLinesWithAccounts = await dao.getGLLinesWithEntriesInDateRange(
      reportStartDate,
      reportEndDate,
    );

    Decimal operatingActivities = Decimal.zero;
    Decimal investingActivities = Decimal.zero;
    Decimal financingActivities = Decimal.zero;

    final cashAccounts = await dao.getAccountsByType('asset');
    final cashAccountIds = cashAccounts
        .where((acc) =>
            acc.code == AccountCodes.cash || acc.code == AccountCodes.bank)
        .map((acc) => acc.id)
        .toSet();

    Decimal beginningCashBalance = Decimal.zero;
    if (reportStartDate != DateTime(2000)) {
      for (var cashAccountId in cashAccountIds) {
        beginningCashBalance +=
            Decimal.parse((await dao.getAccountBalanceAsOfDate(
          cashAccountId,
          reportStartDate.subtract(const Duration(milliseconds: 1)),
        ))
                .toString());
      }
    }

    final entriesMap = <String, List<GLLineWithAccount>>{};
    for (var lineWithAcc in glLinesWithAccounts) {
      entriesMap
          .putIfAbsent(lineWithAcc.line.entryId, () => [])
          .add(lineWithAcc);
    }

    for (var lines in entriesMap.values) {
      Decimal cashMovement = Decimal.zero;
      bool involvesCash = false;
      for (var line in lines) {
        if (cashAccountIds.contains(line.account.id)) {
          cashMovement += (line.line.debit - line.line.credit);
          involvesCash = true;
        }
      }
      if (!involvesCash || cashMovement == Decimal.zero) continue;

      bool categorized = false;
      for (var line in lines) {
        if (!cashAccountIds.contains(line.account.id)) {
          if (line.account.type == 'REVENUE' ||
              line.account.type == 'EXPENSE' ||
              [
                AccountCodes.accountsReceivable,
                AccountCodes.accountsPayable,
                AccountCodes.inputVAT,
                AccountCodes.outputVAT,
              ].contains(line.account.code)) {
            operatingActivities += cashMovement;
            categorized = true;
            break;
          } else if (line.account.code == AccountCodes.fixedAssets) {
            investingActivities += cashMovement;
            categorized = true;
            break;
          } else if ([
            AccountCodes.loansPayable,
            AccountCodes.capital,
          ].contains(line.account.code)) {
            financingActivities += cashMovement;
            categorized = true;
            break;
          }
        }
      }
      if (!categorized) operatingActivities += cashMovement;
    }

    final Decimal netCashFlow =
        operatingActivities + investingActivities + financingActivities;
    return CashFlowData(
      operatingActivities: operatingActivities,
      investingActivities: investingActivities,
      financingActivities: financingActivities,
      netCashFlow: netCashFlow,
      beginningCashBalance: beginningCashBalance,
      endingCashBalance: beginningCashBalance + netCashFlow,
      startDate: reportStartDate,
      endDate: reportEndDate,
    );
  }

  Future<FinancialRatiosData> getFinancialRatios() async {
    final incomeStatement = await getIncomeStatement();
    final dao = db.accountingDao;
    final asOfDate = DateTime.now();

    final allBalances = await dao.getAllAccountBalancesAsOfDate(asOfDate);
    final Map<String, Decimal> balanceByCode = {};
    for (final item in allBalances) {
      balanceByCode[item.account.code] = item.netBalance;
    }

    final Decimal totalRevenue = incomeStatement.totalRevenue;
    final Decimal totalCogs = balanceByCode[AccountCodes.cogs] ?? Decimal.zero;
    final Decimal grossProfit = totalRevenue - totalCogs;
    final Decimal grossProfitMargin = totalRevenue > Decimal.zero
        ? (grossProfit / totalRevenue).toDecimal()
        : Decimal.zero;
    final Decimal netProfitMargin = totalRevenue > Decimal.zero
        ? (incomeStatement.netIncome / totalRevenue).toDecimal()
        : Decimal.zero;

    final Decimal totalCurrentAssets =
        (balanceByCode[AccountCodes.cash] ?? Decimal.zero) +
            (balanceByCode[AccountCodes.bank] ?? Decimal.zero) +
            (balanceByCode[AccountCodes.accountsReceivable] ?? Decimal.zero) +
            (balanceByCode[AccountCodes.inventory] ?? Decimal.zero);

    final Decimal totalCurrentLiabilities =
        (balanceByCode[AccountCodes.accountsPayable] ?? Decimal.zero) +
            (balanceByCode[AccountCodes.outputVAT] ?? Decimal.zero);

    final Decimal currentRatio = totalCurrentLiabilities > Decimal.zero
        ? (totalCurrentAssets / totalCurrentLiabilities).toDecimal()
        : Decimal.zero;

    return FinancialRatiosData(
      grossProfitMargin: grossProfitMargin,
      netProfitMargin: netProfitMargin,
      currentRatio: currentRatio,
    );
  }

  Future<AccountingDashboardData> getDashboardData() async {
    final incomeStatement = await getIncomeStatement();
    final balanceSheet = await getBalanceSheet();
    final ratios = await getFinancialRatios();

    final topExpensesFull =
        List<TrialBalanceItem>.from(incomeStatement.expenses);
    topExpensesFull.sort((a, b) => b.totalDebit.compareTo(a.totalDebit));
    final top5Expenses = topExpensesFull.take(5).toList();

    final recentEntries =
        await db.accountingDao.watchRecentEntries(limit: 5).first;

    final now = DateTime.now();
    final last7Days = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final endDate = last7Days.add(const Duration(days: 7));

    final allRows = await (db.select(db.gLLines).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
      innerJoin(
          db.gLAccounts, db.gLAccounts.id.equalsExp(db.gLLines.accountId)),
    ])
      ..where(db.gLAccounts.accountType.isIn([AccountType.revenue.index, AccountType.expense.index]) &
          db.gLEntries.date.isBetweenValues(last7Days, endDate)))
        .get();

    final Map<DateTime, Decimal> dailyRevMap = {};
    final Map<DateTime, Decimal> dailyExpMap = {};
    for (final row in allRows) {
      final entry = row.readTable(db.gLEntries);
      final line = row.readTable(db.gLLines);
      final account = row.readTable(db.gLAccounts);
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (account.type == 'REVENUE') {
        dailyRevMap[day] =
            (dailyRevMap[day] ?? Decimal.zero) + line.credit - line.debit;
      } else {
        dailyExpMap[day] =
            (dailyExpMap[day] ?? Decimal.zero) + line.debit - line.credit;
      }
    }

    List<DailyValue> dailyRev = [];
    List<DailyValue> dailyExp = [];
    for (int i = 0; i < 7; i++) {
      final date = last7Days.add(Duration(days: i));
      dailyRev.add(DailyValue(date, dailyRevMap[date] ?? Decimal.zero));
      dailyExp.add(DailyValue(date, dailyExpMap[date] ?? Decimal.zero));
    }

    final topProductsFromDao =
        await db.salesDao.getTopSellingProducts(limit: 5);
    final topSellingProducts = topProductsFromDao
        .map((p) => DashboardTopProduct(
            p.product.name, Decimal.parse(p.totalQuantity.toString())))
        .toList();

    final expiringBatches =
        await db.productsDao.getExpiringBatches(daysThreshold: 30);

    return AccountingDashboardData(
      totalRevenue: incomeStatement.totalRevenue,
      totalExpenses: incomeStatement.totalExpense,
      netIncome: incomeStatement.netIncome,
      totalAssets: balanceSheet.totalAssets,
      totalLiabilities: balanceSheet.totalLiabilities,
      topExpenses: top5Expenses,
      recentTransactions: recentEntries,
      dailyRevenue: dailyRev,
      dailyExpenses: dailyExp,
      topSellingProducts: topSellingProducts,
      expiringBatchesCount: expiringBatches.length,
      ratios: ratios,
    );
  }
}
