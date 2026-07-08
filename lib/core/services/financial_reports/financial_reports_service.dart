import 'package:decimal/decimal.dart';
import '../../data/datasources/local/app_database.dart';

/// نموذج بيانات لتقرير الميزانية العمومية
class BalanceSheetData {
  final DateTime asOfDate;
  final List<AccountBalanceItem> assets;
  final List<AccountBalanceItem> liabilities;
  final List<AccountBalanceItem> equity;
  
  Decimal get totalAssets => assets.fold(Decimal.zero, (sum, item) => sum + item.balance);
  Decimal get totalLiabilities => liabilities.fold(Decimal.zero, (sum, item) => sum + item.balance);
  Decimal get totalEquity => equity.fold(Decimal.zero, (sum, item) => sum + item.balance);
  Decimal get totalLiabilitiesAndEquity => totalLiabilities + totalEquity;
  
  bool get isBalanced => (totalAssets - totalLiabilitiesAndEquity).abs() <= Decimal.parse('0.01');
  
  BalanceSheetData({
    required this.asOfDate,
    required this.assets,
    required this.liabilities,
    required this.equity,
  });
}

/// نموذج بيانات لتقرير الدخل
class IncomeStatementData {
  final DateTime startDate;
  final DateTime endDate;
  final List<AccountBalanceItem> revenue;
  final List<AccountBalanceItem> cogs;
  final List<AccountBalanceItem> expenses;
  final List<AccountBalanceItem> otherIncome;
  
  Decimal get totalRevenue => revenue.fold(Decimal.zero, (sum, item) => sum + item.balance);
  Decimal get totalCogs => cogs.fold(Decimal.zero, (sum, item) => sum + item.balance);
  Decimal get grossProfit => totalRevenue - totalCogs;
  Decimal get totalExpenses => expenses.fold(Decimal.zero, (sum, item) => sum + item.balance);
  Decimal get operatingIncome => grossProfit - totalExpenses;
  Decimal get totalOtherIncome => otherIncome.fold(Decimal.zero, (sum, item) => sum + item.balance);
  Decimal get netIncome => operatingIncome + totalOtherIncome;
  
  IncomeStatementData({
    required this.startDate,
    required this.endDate,
    required this.revenue,
    required this.cogs,
    required this.expenses,
    required this.otherIncome,
  });
}

/// عنصر رصيد حسابي
class AccountBalanceItem {
  final String accountId;
  final String accountName;
  final String accountCode;
  final Decimal balance;
  final String? parentAccountId;
  
  AccountBalanceItem({
    required this.accountId,
    required this.accountName,
    required this.accountCode,
    required this.balance,
    this.parentAccountId,
  });
}

/// خدمة توليد التقارير المالية
class FinancialReportsService {
  final AppDatabase db;
  
  FinancialReportsService(this.db);
  
  /// توليد الميزانية العمومية في تاريخ محدد
  Future<BalanceSheetData> generateBalanceSheet(DateTime asOfDate) async {
    // الحصول على جميع الحسابات الرئيسية
    final allAccounts = await (db.select(db.glAccounts)..orderBy([(t) => OrderingTerm.asc(t.code)])).get();
    
    // تصنيف الحسابات حسب نوعها
    final assets = <GLAccount>[];
    final liabilities = <GLAccount>[];
    final equity = <GLAccount>[];
    
    for (var account in allAccounts) {
      switch (account.accountType) {
        case AccountType.asset:
          assets.add(account);
          break;
        case AccountType.liability:
          liabilities.add(account);
          break;
        case AccountType.equity:
          equity.add(account);
          break;
        default:
          break;
      }
    }
    
    // حساب الأرصدة لكل حساب حتى التاريخ المحدد
    final assetItems = await _calculateAccountBalances(assets, asOfDate);
    final liabilityItems = await _calculateAccountBalances(liabilities, asOfDate);
    final equityItems = await _calculateAccountBalances(equity, asOfDate);
    
    // إضافة صافي الدخل إلى حقوق الملكية
    final incomeStatement = await generateIncomeStatement(
      DateTime(asOfDate.year, 1, 1),
      asOfDate,
    );
    
    // إنشاء حساب لصافي الدخل الحالي
    final retainedEarningsItem = AccountBalanceItem(
      accountId: 'retained_earnings_current',
      accountName: 'صافي الدخل للفترة',
      accountCode: '9999',
      balance: incomeStatement.netIncome,
      parentAccountId: null,
    );
    
    return BalanceSheetData(
      asOfDate: asOfDate,
      assets: assetItems,
      liabilities: liabilityItems,
      equity: [...equityItems, retainedEarningsItem],
    );
  }
  
  /// توليد قائمة الدخل لفترة زمنية
  Future<IncomeStatementData> generateIncomeStatement(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final allAccounts = await (db.select(db.glAccounts)..orderBy([(t) => OrderingTerm.asc(t.code)])).get();
    
    final revenue = <GLAccount>[];
    final cogs = <GLAccount>[];
    final expenses = <GLAccount>[];
    final otherIncome = <GLAccount>[];
    
    for (var account in allAccounts) {
      switch (account.accountType) {
        case AccountType.revenue:
          revenue.add(account);
          break;
        case AccountType.cogs:
          cogs.add(account);
          break;
        case AccountType.expense:
          expenses.add(account);
          break;
        case AccountType.otherIncome:
          otherIncome.add(account);
          break;
        default:
          break;
      }
    }
    
    final revenueItems = await _calculateAccountBalances(revenue, endDate, startDate: startDate);
    final cogsItems = await _calculateAccountBalances(cogs, endDate, startDate: startDate);
    final expenseItems = await _calculateAccountBalances(expenses, endDate, startDate: startDate);
    final otherIncomeItems = await _calculateAccountBalances(otherIncome, endDate, startDate: startDate);
    
    return IncomeStatementData(
      startDate: startDate,
      endDate: endDate,
      revenue: revenueItems,
      cogs: cogsItems,
      expenses: expenseItems,
      otherIncome: otherIncomeItems,
    );
  }
  
  /// حساب أرصدة الحسابات
  Future<List<AccountBalanceItem>> _calculateAccountBalances(
    List<GLAccount> accounts,
    DateTime endDate, {
    DateTime? startDate,
  }) async {
    final items = <AccountBalanceItem>[];
    
    for (var account in accounts) {
      final balance = await _calculateAccountBalance(account.id, endDate, startDate: startDate);
      
      if (balance != Decimal.zero) {
        items.add(AccountBalanceItem(
          accountId: account.id,
          accountName: account.name,
          accountCode: account.code,
          balance: balance,
          parentAccountId: account.parentId,
        ));
      }
    }
    
    return items;
  }
  
  /// حساب رصيد حساب واحد
  Future<Decimal> _calculateAccountBalance(
    String accountId,
    DateTime endDate, {
    DateTime? startDate,
  }) async {
    var query = db.select(db.glLines).join([
      innerJoin(db.glEntries, db.glEntries.id.equalsExp(db.glLines.entryId)),
    ])
      ..where(db.glLines.accountId.equals(accountId))
      ..where(db.glEntries.date.isSmallerOrEqualValue(endDate));
    
    if (startDate != null) {
      query = query..where(db.glEntries.date.isBiggerOrEqualValue(startDate));
    }
    
    final lines = await query.get();
    
    Decimal debitTotal = Decimal.zero;
    Decimal creditTotal = Decimal.zero;
    
    for (final row in lines) {
      final glLine = row.readTable(db.glLines);
      debitTotal = debitTotal + glLine.debit;
      creditTotal = creditTotal + glLine.credit;
    }
    
    // تحديد نوع الحساب لتحديد اتجاه الرصيد
    final account = await (db.select(db.glAccounts)..where((t) => t.id.equals(accountId))).getSingle();
    
    // الحسابات المدينة (Assets, Expenses): الرصيد = مدين - دائن
    // الحسابات الدائنة (Liabilities, Equity, Revenue): الرصيد = دائن - مدين
    if (account.accountType == AccountType.asset || 
        account.accountType == AccountType.expense ||
        account.accountType == AccountType.cogs) {
      return debitTotal - creditTotal;
    } else {
      return creditTotal - debitTotal;
    }
  }
  
  /// توليد تقرير التدفقات النقدية
  Future<Map<String, Decimal>> generateCashFlowStatement(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // تبسيط: حساب صافي التدفق من العمليات التشغيلية
    final cashAccounts = await (db.select(db.glAccounts)
      ..where((t) => t.accountType.equalsExp(const Constant('asset')))
      ..where((t) => t.name.like('%نقد%'))).get();
    
    final cashFlows = <String, Decimal>{};
    
    for (var account in cashAccounts) {
      final startBalance = await _calculateAccountBalance(account.id, startDate);
      final endBalance = await _calculateAccountBalance(account.id, endDate);
      final change = endBalance - startBalance;
      
      cashFlows[account.name] = change;
    }
    
    return cashFlows;
  }
  
  /// توليد ميزان المراجعة
  Future<List<AccountBalanceItem>> generateTrialBalance(DateTime asOfDate) async {
    final allAccounts = await (db.select(db.glAccounts)..orderBy([(t) => OrderingTerm.asc(t.code)])).get();
    final items = <AccountBalanceItem>[];
    
    for (var account in allAccounts) {
      final balance = await _calculateAccountBalance(account.id, asOfDate);
      
      items.add(AccountBalanceItem(
        accountId: account.id,
        accountName: account.name,
        accountCode: account.code,
        balance: balance.abs(),
        parentAccountId: account.parentId,
      ));
    }
    
    return items;
  }
  
  /// توليد دفتر الأستاذ العام لحساب معين
  Future<List<Map<String, dynamic>>> generateGeneralLedger(
    String accountId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = db.select(db.glLines).join([
      innerJoin(db.glEntries, db.glEntries.id.equalsExp(db.glLines.entryId)),
    ])
      ..where(db.glLines.accountId.equals(accountId))
      ..where(db.glEntries.date.isBiggerOrEqualValue(startDate))
      ..where(db.glEntries.date.isSmallerOrEqualValue(endDate))
      ..orderBy([(t) => OrderingTerm.asc(db.glEntries.date)]);
    
    final lines = await query.get();
    final result = <Map<String, dynamic>>[];
    
    for (final row in lines) {
      final glLine = row.readTable(db.glLines);
      final glEntry = row.readTable(db.glEntries);
      
      result.add({
        'date': glEntry.date,
        'entryId': glEntry.id,
        'reference': glEntry.reference,
        'description': glEntry.description,
        'debit': glLine.debit,
        'credit': glLine.credit,
        'balance': glLine.debit - glLine.credit, // سيتم حسابه تراكمياً في العرض
      });
    }
    
    return result;
  }
}
