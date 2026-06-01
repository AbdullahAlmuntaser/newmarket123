import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';
import 'audit_service.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'event_bus_service.dart';
import 'package:json_annotation/json_annotation.dart';
import 'dart:developer' as developer;
import 'app_config_service.dart';
import 'permission_service.dart';
import 'budget_service.dart';
import 'package:supermarket/injection_container.dart';

part 'accounting_service.g.dart';

@JsonSerializable(explicitToJson: true)
class AccountingDashboardData {
  final double totalRevenue;
  final double totalExpenses;
  final double netIncome;
  final double totalAssets;
  final double totalLiabilities;
  final List<TrialBalanceItem> topExpenses;
  @GLEntryConverter()
  final List<GLEntry> recentTransactions;
  final List<DailyValue> dailyRevenue;
  final List<DailyValue> dailyExpenses;
  final List<DashboardTopProduct> topSellingProducts;
  final int expiringBatchesCount;
  final FinancialRatiosData ratios;

  AccountingDashboardData({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netIncome,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.topExpenses,
    required this.recentTransactions,
    required this.dailyRevenue,
    required this.dailyExpenses,
    required this.topSellingProducts,
    this.expiringBatchesCount = 0,
    required this.ratios,
  });

  factory AccountingDashboardData.fromJson(Map<String, dynamic> json) =>
      _$AccountingDashboardDataFromJson(json);
  Map<String, dynamic> toJson() => _$AccountingDashboardDataToJson(this);
}

@JsonSerializable()
class DashboardTopProduct {
  final String productName;
  final double quantity;
  DashboardTopProduct(this.productName, this.quantity);

  factory DashboardTopProduct.fromJson(Map<String, dynamic> json) =>
      _$DashboardTopProductFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardTopProductToJson(this);
}

@JsonSerializable()
class DailyValue {
  final DateTime date;
  final double value;
  DailyValue(this.date, this.value);

  factory DailyValue.fromJson(Map<String, dynamic> json) =>
      _$DailyValueFromJson(json);
  Map<String, dynamic> toJson() => _$DailyValueToJson(this);
}

@JsonSerializable()
class CashFlowData {
  final double operatingActivities;
  final double investingActivities;
  final double financingActivities;
  final double netCashFlow;
  final double beginningCashBalance;
  final double endingCashBalance;
  final DateTime? startDate;
  final DateTime endDate;

  CashFlowData({
    required this.operatingActivities,
    required this.investingActivities,
    required this.financingActivities,
    required this.netCashFlow,
    required this.beginningCashBalance,
    required this.endingCashBalance,
    this.startDate,
    required this.endDate,
  });

  factory CashFlowData.fromJson(Map<String, dynamic> json) =>
      _$CashFlowDataFromJson(json);
  Map<String, dynamic> toJson() => _$CashFlowDataToJson(this);
}

@JsonSerializable()
class FinancialRatiosData {
  final double grossProfitMargin;
  final double netProfitMargin;
  final double currentRatio;

  FinancialRatiosData({
    required this.grossProfitMargin,
    required this.netProfitMargin,
    required this.currentRatio,
  });

  factory FinancialRatiosData.fromJson(Map<String, dynamic> json) =>
      _$FinancialRatiosDataFromJson(json);
  Map<String, dynamic> toJson() => _$FinancialRatiosDataToJson(this);
}

@JsonSerializable()
class VatReportData {
  final Decimal totalTaxableSales;
  final Decimal totalOutputVat;
  final Decimal totalTaxablePurchases;
  final Decimal totalInputVat;
  final Decimal netVatPayable;
  final DateTime startDate;
  final DateTime endDate;

  VatReportData({
    required this.totalTaxableSales,
    required this.totalOutputVat,
    required this.totalTaxablePurchases,
    required this.totalInputVat,
    required this.netVatPayable,
    required this.startDate,
    required this.endDate,
  });

  factory VatReportData.fromJson(Map<String, dynamic> json) =>
      _$VatReportDataFromJson(json);
  Map<String, dynamic> toJson() => _$VatReportDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class IncomeStatementData {
  final List<TrialBalanceItem> revenues;
  final List<TrialBalanceItem> expenses;
  final double totalRevenue;
  final double totalExpense;
  final double netIncome;
  final DateTime? startDate;
  final DateTime endDate;

  IncomeStatementData({
    required this.revenues,
    required this.expenses,
    required this.totalRevenue,
    required this.totalExpense,
    required this.netIncome,
    this.startDate,
    required this.endDate,
  });

  factory IncomeStatementData.fromJson(Map<String, dynamic> json) =>
      _$IncomeStatementDataFromJson(json);
  Map<String, dynamic> toJson() => _$IncomeStatementDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class BalanceSheetData {
  final List<BalanceSheetItem> assets;
  final List<BalanceSheetItem> liabilities;
  final List<BalanceSheetItem> equity;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final double netIncome;
  final DateTime date;

  BalanceSheetData({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.netIncome,
    required this.date,
  });

  factory BalanceSheetData.fromJson(Map<String, dynamic> json) =>
      _$BalanceSheetDataFromJson(json);
  Map<String, dynamic> toJson() => _$BalanceSheetDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class BalanceSheetItem {
  @GLAccountConverter()
  final GLAccount account;
  final double balance;

  BalanceSheetItem(this.account, this.balance);

  factory BalanceSheetItem.fromJson(Map<String, dynamic> json) =>
      _$BalanceSheetItemFromJson(json);
  Map<String, dynamic> toJson() => _$BalanceSheetItemToJson(this);
}

class GLAccountConverter
    implements JsonConverter<GLAccount, Map<String, dynamic>> {
  const GLAccountConverter();

  @override
  GLAccount fromJson(Map<String, dynamic> json) => GLAccount.fromJson(json);

  @override
  Map<String, dynamic> toJson(GLAccount object) => object.toJson();
}

class GLEntryConverter implements JsonConverter<GLEntry, Map<String, dynamic>> {
  const GLEntryConverter();

  @override
  GLEntry fromJson(Map<String, dynamic> json) => GLEntry.fromJson(json);

  @override
  Map<String, dynamic> toJson(GLEntry object) => object.toJson();
}

class AccountingService {
  final AppDatabase db;
  final EventBusService eventBus;
  late final AuditService _auditService;
  late final AppConfigService _configService;
  late final PermissionService _permissionService;

  AccountingService(this.db, this.eventBus) {
    _auditService = AuditService(db);
    _configService = AppConfigService(db);
    _permissionService = PermissionService(db);
    _listenToEvents();
  }

  void _listenToEvents() {
    eventBus.stream.listen((event) {
      developer.log('AccountingService: Received event ${event.runtimeType}',
          name: 'accounting.service');
      if (event is CustomerPaymentEvent) {
        _handleCustomerPayment(event);
      } else if (event is SupplierPaymentEvent) {
        _handleSupplierPayment(event);
      } else if (event is CashTransactionEvent) {
        _handleCashTransaction(event);
      }
    });
  }

  Future<void> _handleCashTransaction(CashTransactionEvent event) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();
    final cashAccount = await dao.getAccountByCode(codeCash);
    if (cashAccount == null) return;

    final defaultBranchId = await _configService.getDefaultBranchId();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: '${event.type == "IN" ? "سند قبض" : "سند صرف"}: ${event.category} - ${event.note ?? ""}',
      date: Value(DateTime.now()),
      referenceType: Value(event.type == "IN" ? 'RECEIPT' : 'PAYMENT'),
      referenceId: Value(event.referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(defaultBranchId),
    );

    final lines = event.type == "IN"
        ? [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: cashAccount.id,
              debit: Value(event.amount),
              credit: Value(Decimal.zero),
              branchId: Value(defaultBranchId),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: event.accountId,
              debit: Value(Decimal.zero),
              credit: Value(event.amount),
              branchId: Value(defaultBranchId),
            ),
          ]
        : [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: event.accountId,
              debit: Value(event.amount),
              credit: Value(Decimal.zero),
              branchId: Value(defaultBranchId),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: cashAccount.id,
              debit: Value(Decimal.zero),
              credit: Value(event.amount),
              branchId: Value(defaultBranchId),
            ),
          ];

    await dao.createEntry(entry, lines);
  }


  /// New: Generic journal entry creation from events
  Future<void> createJournalEntry(AppEvent event) async {
    if (event is SaleCreatedEvent) {
      await postSale(event.sale, event.items, cogs: event.cogs);
    }
  }

  Future<void> _recordAccountTransaction({
    required String accountId,
    required String type,
    String? referenceId,
    Decimal? debit,
    Decimal? credit,
    DateTime? date,
    String? branchId,
  }) async {
    await db.transaction(() async {
      // الحصول على معرف الفرع الافتراضي من الإعدادات
      final effectiveBranchId =
          branchId ?? await _configService.getDefaultBranchId();

      await db.into(db.accountTransactions).insert(
            AccountTransactionsCompanion.insert(
              accountId: accountId,
              date: Value(date ?? DateTime.now()),
              type: type,
              referenceId: Value(referenceId),
              debit: Value(debit ?? Decimal.zero),
              credit: Value(credit ?? Decimal.zero),
              branchId: Value(effectiveBranchId),
            ),
          );
    });
  }

  Future<void> _handleCustomerPayment(CustomerPaymentEvent event) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    // Accounts
    final arAccount = await dao.getAccountByCode(codeAccountsReceivable);
    final cashAccount = await dao.getAccountByCode(codeCash);

    if (arAccount == null || cashAccount == null) return;

    final customer = await db.customersDao.getCustomerById(event.customerId);
    final customerAccountId = customer?.accountId ?? arAccount.id;

    // الحصول على معرف الفرع الافتراضي من الإعدادات
    final defaultBranchId = await _configService.getDefaultBranchId();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'سند قبض: ${customer?.name ?? "عميل"} - ${event.note ?? ""}',
      date: Value(DateTime.now()),
      referenceType: const Value('RECEIPT'),
      referenceId: Value(event.paymentId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(defaultBranchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: cashAccount.id,
        debit: Value(event.amount),
        credit: Value(Decimal.zero),
        branchId: Value(defaultBranchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: customerAccountId,
        debit: Value(Decimal.zero),
        credit: Value(event.amount),
        branchId: Value(defaultBranchId),
      ),
    ];

    await dao.createEntry(entry, lines);

    // Record in AccountTransactions for fast statements
    await _recordAccountTransaction(
      accountId: customerAccountId,
      type: 'PAYMENT',
      referenceId: event.paymentId,
      credit: event.amount,
      branchId: defaultBranchId,
    );
  }

  Future<void> _handleSupplierPayment(SupplierPaymentEvent event) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    // Accounts
    final apAccount = await dao.getAccountByCode(codeAccountsPayable);
    final cashAccount = await dao.getAccountByCode(codeCash);

    if (apAccount == null || cashAccount == null) return;

    final supplier = await db.suppliersDao.getSupplierById(event.supplierId);
    final supplierAccountId = supplier?.accountId ?? apAccount.id;

    // الحصول على معرف الفرع الافتراضي من الإعدادات
    final defaultBranchId = await _configService.getDefaultBranchId();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'سند صرف: ${supplier?.name ?? "مورد"} - ${event.note ?? ""}',
      date: Value(DateTime.now()),
      referenceType: const Value('PAYMENT'),
      referenceId: Value(event.paymentId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(defaultBranchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: supplierAccountId,
        debit: Value(event.amount),
        credit: Value(Decimal.zero),
        branchId: Value(defaultBranchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: cashAccount.id,
        debit: Value(Decimal.zero),
        credit: Value(event.amount),
        branchId: Value(defaultBranchId),
      ),
    ];

    await dao.createEntry(entry, lines);

    // Record in AccountTransactions for fast statements
    await _recordAccountTransaction(
      accountId: supplierAccountId,
      type: 'PAYMENT',
      referenceId: event.paymentId,
      debit: event.amount,
      branchId: defaultBranchId,
    );
  }

  // Standard Account Codes
  static const String codeCash = '1010';
  static const String codeBank = '1020';
  static const String codeAccountsReceivable = '1030';
  static const String codeInventory = '1040';
  static const String codeInputVAT = '1050';
  static const String codeFixedAssets = '1200';
  static const String codeAccumulatedDepreciation = '1201';
  static const String codeAccountsPayable = '2010';
  static const String codeOutputVAT = '2020';
  static const String codeLoansPayable = '2500';
  static const String codeCapital = '3000';
  static const String codeRetainedEarnings = '3010';
  static const String codeSalesRevenue = '4010';
  static const String codeSalesReturns = '4020';
  static const String codeCOGS = '5010';
  static const String codePurchaseReturns = '5011';
  static const String codeCashOverShort = '5020';
  static const String codeOperatingExpenses = '6000';
  static const String codeDepreciationExpense = '6001';

  Future<void> seedDefaultAccounts({String? branchId}) async {
    final dao = db.accountingDao;
    // الحصول على معرف الفرع الافتراضي من الإعدادات إذا لم يتم تحديده
    final effectiveBranchId =
        branchId ?? await _configService.getDefaultBranchId();

    final accounts = {
      codeCash: GLAccountsCompanion.insert(
        code: codeCash,
        name: 'الصندوق',
        type: 'ASSET',
        branchId: Value(effectiveBranchId),
      ),
      codeBank: GLAccountsCompanion.insert(
        code: codeBank,
        name: 'البنك',
        type: 'ASSET',
        branchId: Value(effectiveBranchId),
      ),
      codeAccountsReceivable: GLAccountsCompanion.insert(
        code: codeAccountsReceivable,
        name: 'الذمم المدينة',
        type: 'ASSET',
        branchId: Value(effectiveBranchId),
      ),
      codeInventory: GLAccountsCompanion.insert(
        code: codeInventory,
        name: 'المخزون',
        type: 'ASSET',
        branchId: Value(effectiveBranchId),
      ),
      codeInputVAT: GLAccountsCompanion.insert(
        code: codeInputVAT,
        name: 'ضريبة المدخلات (المشتريات)',
        type: 'ASSET',
        branchId: Value(effectiveBranchId),
      ),
      codeFixedAssets: GLAccountsCompanion.insert(
        code: codeFixedAssets,
        name: 'الأصول الثابتة',
        type: 'ASSET',
        isHeader: const Value(true),
        branchId: Value(effectiveBranchId),
      ),
      codeAccumulatedDepreciation: GLAccountsCompanion.insert(
        code: codeAccumulatedDepreciation,
        name: 'مجمع الإهلاك',
        type: 'ASSET',
        branchId: Value(effectiveBranchId),
      ),
      codeAccountsPayable: GLAccountsCompanion.insert(
        code: codeAccountsPayable,
        name: 'الذمم الدائنة',
        type: 'LIABILITY',
        branchId: Value(effectiveBranchId),
      ),
      codeOutputVAT: GLAccountsCompanion.insert(
        code: codeOutputVAT,
        name: 'ضريبة المخرجات (المبيعات)',
        type: 'LIABILITY',
        branchId: Value(effectiveBranchId),
      ),
      codeLoansPayable: GLAccountsCompanion.insert(
        code: codeLoansPayable,
        name: 'القروض',
        type: 'LIABILITY',
        branchId: Value(effectiveBranchId),
      ),
      codeCapital: GLAccountsCompanion.insert(
        code: codeCapital,
        name: 'رأس المال',
        type: 'EQUITY',
        branchId: Value(effectiveBranchId),
      ),
      codeRetainedEarnings: GLAccountsCompanion.insert(
        code: codeRetainedEarnings,
        name: 'الأرباح المحتجزة',
        type: 'EQUITY',
        branchId: Value(effectiveBranchId),
      ),
      codeSalesRevenue: GLAccountsCompanion.insert(
        code: codeSalesRevenue,
        name: 'إيرادات المبيعات',
        type: 'REVENUE',
        branchId: Value(effectiveBranchId),
      ),
      codeSalesReturns: GLAccountsCompanion.insert(
        code: codeSalesReturns,
        name: 'مردودات المبيعات',
        type: 'REVENUE',
        branchId: Value(effectiveBranchId),
      ),
      codeCOGS: GLAccountsCompanion.insert(
        code: codeCOGS,
        name: 'تكلفة البضاعة المباعة',
        type: 'EXPENSE',
        branchId: Value(effectiveBranchId),
      ),
      codePurchaseReturns: GLAccountsCompanion.insert(
        code: codePurchaseReturns,
        name: 'مردودات المشتريات',
        type: 'EXPENSE',
        branchId: Value(effectiveBranchId),
      ),
      codeCashOverShort: GLAccountsCompanion.insert(
        code: codeCashOverShort,
        name: 'العجز والزيادة في الصندوق',
        type: 'EXPENSE',
        branchId: Value(effectiveBranchId),
      ),
      codeOperatingExpenses: GLAccountsCompanion.insert(
        code: codeOperatingExpenses,
        name: 'المصروفات التشغيلية',
        type: 'EXPENSE',
        isHeader: const Value(true),
        branchId: Value(effectiveBranchId),
      ),
      codeDepreciationExpense: GLAccountsCompanion.insert(
        code: codeDepreciationExpense,
        name: 'مصروف الإهلاك',
        type: 'EXPENSE',
        branchId: Value(effectiveBranchId),
      ),
    };

    for (var acc in accounts.values) {
      final existing = await dao.getAccountByCode(acc.code.value);
      if (existing == null) {
        await dao.createAccount(acc);
      } else if (existing.branchId == null && branchId != null) {
        await dao.updateAccount(existing.copyWith(branchId: Value(branchId)));
      }
    }
  }

  Future<FinancialRatiosData> getFinancialRatios() async {
    final incomeStatement = await getIncomeStatement();
    final dao = db.accountingDao;
    final asOfDate = DateTime.now();

    final cogsAccount = await dao.getAccountByCode(codeCOGS);
    final cogsBalance = cogsAccount != null
        ? await dao.getAccountBalanceAsOfDate(cogsAccount.id, asOfDate)
        : Decimal.zero;
    final double totalRevenue = incomeStatement.totalRevenue;
    final double totalCogs = double.parse(cogsBalance.toString());
    final double grossProfit = totalRevenue - totalCogs;
    final grossProfitMargin = totalRevenue > 0
        ? (grossProfit / totalRevenue)
        : 0.0;

    final netProfitMargin = totalRevenue > 0
        ? (incomeStatement.netIncome / totalRevenue)
        : 0.0;

    final currentAssetCodes = [
      codeCash,
      codeBank,
      codeAccountsReceivable,
      codeInventory,
    ];
    final currentLiabilityCodes = [codeAccountsPayable, codeOutputVAT];

    Decimal totalCurrentAssets = Decimal.zero;
    for (var code in currentAssetCodes) {
      final account = await dao.getAccountByCode(code);
      if (account != null) {
        totalCurrentAssets += Decimal.parse((await dao.getAccountBalanceAsOfDate(
          account.id,
          asOfDate,
        )).toString());
      }
    }

    Decimal totalCurrentLiabilities = Decimal.zero;
    for (var code in currentLiabilityCodes) {
      final account = await dao.getAccountByCode(code);
      if (account != null) {
        totalCurrentLiabilities += Decimal.parse((await dao.getAccountBalanceAsOfDate(
          account.id,
          asOfDate,
        )).toString());
      }
    }

    final currentRatio = totalCurrentLiabilities > Decimal.zero
        ? (totalCurrentAssets / totalCurrentLiabilities).toDouble()
        : 0.0;

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

    final topExpensesFull = List<TrialBalanceItem>.from(
      incomeStatement.expenses,
    );
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

    List<DailyValue> dailyRev = [];
    List<DailyValue> dailyExp = [];

    for (int i = 0; i < 7; i++) {
      final date = last7Days.add(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));
      
      final revQuery = db.select(db.gLLines).join([
        innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
        innerJoin(db.gLAccounts, db.gLAccounts.id.equalsExp(db.gLLines.accountId)),
      ])
        ..where(db.gLAccounts.type.equals('REVENUE') & 
                db.gLEntries.date.isBiggerOrEqual(Variable(date)) & 
                db.gLEntries.date.isSmallerThan(Variable(nextDate)));
      
      final revRows = await revQuery.get();
      Decimal revTotal = revRows.fold(Decimal.zero, (sum, row) => sum + ((row.read(db.gLLines.credit) as Decimal?) ?? Decimal.zero) - ((row.read(db.gLLines.debit) as Decimal?) ?? Decimal.zero));
      dailyRev.add(DailyValue(date, revTotal.toDouble()));

      final expQuery = db.select(db.gLLines).join([
        innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
        innerJoin(db.gLAccounts, db.gLAccounts.id.equalsExp(db.gLLines.accountId)),
      ])
        ..where(db.gLAccounts.type.equals('EXPENSE') & 
                db.gLEntries.date.isBiggerOrEqual(Variable(date)) & 
                db.gLEntries.date.isSmallerThan(Variable(nextDate)));

      final expRows = await expQuery.get();
      Decimal expTotal = expRows.fold(Decimal.zero, (sum, row) => sum + ((row.read(db.gLLines.debit) as Decimal?) ?? Decimal.zero) - ((row.read(db.gLLines.credit) as Decimal?) ?? Decimal.zero));
      dailyExp.add(DailyValue(date, expTotal.toDouble()));
    }

    final topProductsFromDao = await db.salesDao.getTopSellingProducts(
      limit: 5,
    );
    final topSellingProducts = topProductsFromDao
        .map((p) => DashboardTopProduct(p.product.name, p.totalQuantity.toDouble()))
        .toList();

    final expiringBatches = await db.productsDao.getExpiringBatches(
      daysThreshold: 30,
    );

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

  Future<String> createCustomerAccount(String customerName) async {
    final dao = db.accountingDao;
    await db.ensureCoreReferenceData();
    var parent = await dao.getAccountByCode(codeAccountsReceivable);
    parent ??= await dao.getAccountByCode('1201');
    if (parent == null) {
      throw Exception('حساب الذمم المدينة الرئيسي غير موجود. تعذر إنشاء حساب العميل.');
    }
    final parentAccount = parent;

    final existingSubAccounts = await (db.select(
      db.gLAccounts,
    )..where((a) => a.parentId.equals(parentAccount.id)))
        .get();
    final nextNumber = (existingSubAccounts.length + 1).toString().padLeft(
          4,
          '0',
        );
    final newCode = '${parentAccount.code}.$nextNumber';

    final id = const Uuid().v4();
    final defaultBranchId = await _configService.getDefaultBranchId();
    final branch = await (db.select(db.branches)
          ..where((b) => b.id.equals(defaultBranchId)))
        .getSingleOrNull();
    if (branch == null) {
      throw Exception('الفرع الافتراضي غير موجود. تعذر إنشاء حساب العميل.');
    }
    await dao.createAccount(
      GLAccountsCompanion.insert(
        id: Value(id),
        code: newCode,
        name: 'حساب عميل: $customerName',
        type: 'ASSET',
        parentId: Value(parentAccount.id),
        branchId: Value(defaultBranchId),
      ),
    );
    return id;
  }

  Future<String> createSupplierAccount(String supplierName) async {
    final dao = db.accountingDao;
    await db.ensureCoreReferenceData();
    final parent = await dao.getAccountByCode(codeAccountsPayable);
    if (parent == null) {
      throw Exception('حساب الذمم الدائنة الرئيسي غير موجود. تعذر إنشاء حساب المورد.');
    }

    final existingSubAccounts = await (db.select(
      db.gLAccounts,
    )..where((a) => a.parentId.equals(parent.id)))
        .get();
    final nextNumber = (existingSubAccounts.length + 1).toString().padLeft(
          4,
          '0',
        );
    final newCode = '${parent.code}.$nextNumber';

    final id = const Uuid().v4();
    final defaultBranchId = await _configService.getDefaultBranchId();
    final branch = await (db.select(db.branches)
          ..where((b) => b.id.equals(defaultBranchId)))
        .getSingleOrNull();
    if (branch == null) {
      throw Exception('الفرع الافتراضي غير موجود. تعذر إنشاء حساب المورد.');
    }
    await dao.createAccount(
      GLAccountsCompanion.insert(
        id: Value(id),
        code: newCode,
        name: 'حساب مورد: $supplierName',
        type: 'LIABILITY',
        parentId: Value(parent.id),
        branchId: Value(defaultBranchId),
      ),
    );
    return id;
  }

  Future<void> postSale(Sale sale, List<SaleItem> items,
      {Decimal? cogs, String? userId}) async {
    try {
      if (userId != null) {
        await _permissionService.executeIfAllowed(
            userId, PermissionCode.postSale, () async {});
      }
      if (await db.accountingDao.isDateInClosedPeriod(sale.createdAt)) {
        throw Exception('Cannot post sale in a closed accounting period.');
      }
      await db.transaction(() async {
        final dao = db.accountingDao;
        final entryId = const Uuid().v4();

        String debitAccountId;
        if (sale.isCredit) {
          if (sale.customerId == null) {
            throw Exception('Credit sale must have a customer.');
          }
          final customer =
              await db.customersDao.getCustomerById(sale.customerId!);
          if (customer?.accountId == null) {
            debitAccountId = (await dao.getAccountByCode(
              codeAccountsReceivable,
            ))!
                .id;
          } else {
            debitAccountId = customer!.accountId!;
          }
        } else {
          debitAccountId = (await dao.getAccountByCode(codeCash))!.id;
        }

        final revenueAccount = await dao.getAccountByCode(codeSalesRevenue);
        final taxAccount = await dao.getAccountByCode(codeOutputVAT);

        if (revenueAccount == null || taxAccount == null) {
          throw Exception('Missing one or more required GL accounts for sale.');
        }

        final entry = GLEntriesCompanion.insert(
          id: Value(entryId),
          description: 'Sale #${sale.id.substring(0, 8)}',
          date: Value(sale.createdAt),
          referenceType: const Value('SALE'),
          referenceId: Value(sale.id),
          status: const Value('POSTED'),
          postedAt: Value(DateTime.now()),
          currencyId: Value(sale.currencyId),
          exchangeRate: Value(sale.exchangeRate),
          branchId:
              Value(sale.branchId ?? await _configService.getDefaultBranchId()),
        );

        final lines = [
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: debitAccountId,
            debit: Value(sale.total),
            credit: Value(Decimal.zero),
            currencyId: Value(sale.currencyId),
            exchangeRate: Value(sale.exchangeRate),
            branchId: Value(
                sale.branchId ?? await _configService.getDefaultBranchId()),
          ),
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: revenueAccount.id,
            debit: Value(Decimal.zero),
            credit: Value(sale.total - sale.tax),
            currencyId: Value(sale.currencyId),
            exchangeRate: Value(sale.exchangeRate),
            branchId: Value(
                sale.branchId ?? await _configService.getDefaultBranchId()),
          ),
          if (sale.tax > Decimal.zero)
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: taxAccount.id,
              debit: Value(Decimal.zero),
              credit: Value(sale.tax),
              currencyId: Value(sale.currencyId),
              exchangeRate: Value(sale.exchangeRate),
              branchId: Value(
                  sale.branchId ?? await _configService.getDefaultBranchId()),
            ),
        ];

        await dao.createEntry(entry, lines);

        // Record in AccountTransactions if credit
        if (sale.isCredit) {
          await _recordAccountTransaction(
            accountId: debitAccountId,
            type: 'INVOICE',
            referenceId: sale.id,
            debit: sale.total,
            date: sale.createdAt,
            branchId:
                sale.branchId ?? await _configService.getDefaultBranchId(),
          );
        }

        await _auditService.logCreate(
          'GLEntry',
          entryId,
          details: 'Revenue entry for Sale #${sale.id.substring(0, 8)}',
        );

        // Use actual COGS from event (calculated from batches) or calculate from batch costs
        final Decimal totalCost = cogs ?? Decimal.zero;
        Decimal calculatedCost = Decimal.zero;
        if (totalCost == Decimal.zero) {
          for (var item in items) {
            final batches = await (db.select(db.productBatches)
                  ..where((b) => b.productId.equals(item.productId))
                  ..where((b) => b.quantity.isBiggerThan(Constant(Decimal.zero.toString())))
                  ..orderBy([
                    (b) => OrderingTerm(
                          expression: b.expiryDate.isNull(),
                          mode: OrderingMode.asc,
                        ),
                    (b) => OrderingTerm(
                          expression: b.expiryDate,
                          mode: OrderingMode.asc,
                        ),
                    (b) => OrderingTerm(
                          expression: b.createdAt,
                          mode: OrderingMode.asc,
                        ),
                  ]))
                .get();
            Decimal remainingQty = item.quantity * item.unitFactor;
            for (var batch in batches) {
              if (remainingQty <= Decimal.zero) break;
              Decimal deductFromBatch = batch.quantity >= remainingQty
                  ? remainingQty
                  : batch.quantity;
              calculatedCost += deductFromBatch * batch.costPrice;
              remainingQty -= deductFromBatch;
            }
          }
        }

        final Decimal finalCost = totalCost > Decimal.zero ? totalCost : calculatedCost;

        if (finalCost > Decimal.zero) {
          final cogsEntryId = const Uuid().v4();
          final cogsAccount = await dao.getAccountByCode(codeCOGS);
          final inventoryAccount = await dao.getAccountByCode(codeInventory);

          if (cogsAccount != null && inventoryAccount != null) {
            final cogsEntry = GLEntriesCompanion.insert(
              id: Value(cogsEntryId),
              description: 'COGS for Sale #${sale.id.substring(0, 8)}',
              date: Value(sale.createdAt),
              referenceType: const Value('COGS'),
              referenceId: Value(sale.id),
              status: const Value('POSTED'),
              postedAt: Value(DateTime.now()),
              branchId: Value(
                  sale.branchId ?? await _configService.getDefaultBranchId()),
            );

            final cogsLines = [
              GLLinesCompanion.insert(
                entryId: cogsEntryId,
                accountId: cogsAccount.id,
                debit: Value(finalCost),
                credit: Value(Decimal.zero),
                branchId: Value(
                    sale.branchId ?? await _configService.getDefaultBranchId()),
              ),
              GLLinesCompanion.insert(
                entryId: cogsEntryId,
                accountId: inventoryAccount.id,
                debit: Value(Decimal.zero),
                credit: Value(finalCost),
                branchId: Value(
                    sale.branchId ?? await _configService.getDefaultBranchId()),
              ),
            ];
            await dao.createEntry(cogsEntry, cogsLines);
          }
        }
      });
    } catch (e, s) {
      developer.log('Error posting sale', error: e, stackTrace: s);
      final String errorMessage = e.toString();
      throw Exception('Failed to post sale: $errorMessage \n StackTrace: $s');
    }
  }

  Future<void> postPurchase(Purchase purchase, List<PurchaseItem> items,
      {String? userId}) async {
    try {
      if (userId != null) {
        await _permissionService.executeIfAllowed(
            userId, 'POST_PURCHASE', () async {});
      }
      if (await db.accountingDao.isDateInClosedPeriod(purchase.date)) {
        throw Exception('Cannot post purchase in a closed accounting period.');
      }
      await db.transaction(() async {
        final dao = db.accountingDao;
        final entryId = const Uuid().v4();

        final inventoryAccount = await dao.getAccountByCode(codeInventory);
        final taxAccount = await dao.getAccountByCode(codeInputVAT);

        String creditAccountId;
        if (purchase.isCredit) {
          if (purchase.supplierId == null) {
            throw Exception('Credit purchase must have a supplier.');
          }
          final supplier = await db.suppliersDao.getSupplierById(
            purchase.supplierId!,
          );
          creditAccountId = supplier?.accountId ??
              (await dao.getAccountByCode(codeAccountsPayable))!.id;
        } else {
          creditAccountId = (await dao.getAccountByCode(codeCash))!.id;
        }

        if (inventoryAccount == null || taxAccount == null) {
          throw Exception('Missing GL accounts for purchase.');
        }

        final Decimal inventoryValue = purchase.total - purchase.tax;

        final entry = GLEntriesCompanion.insert(
          id: Value(entryId),
          description: 'إثبات فاتورة مشتريات #${purchase.id.substring(0, 8)}',
          date: Value(purchase.date),
          referenceType: const Value('PURCHASE'),
          referenceId: Value(purchase.id),
          status: const Value('POSTED'),
          postedAt: Value(DateTime.now()),
          currencyId: Value(purchase.currencyId),
          exchangeRate: Value(purchase.exchangeRate),
          branchId: Value(
              purchase.branchId ?? await _configService.getDefaultBranchId()),
        );

        final lines = [
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: inventoryAccount.id,
            debit: Value(inventoryValue),
            credit: Value(Decimal.zero),
            currencyId: Value(purchase.currencyId),
            exchangeRate: Value(purchase.exchangeRate),
            branchId: Value(
                purchase.branchId ?? await _configService.getDefaultBranchId()),
          ),
          if (purchase.tax > Decimal.zero)
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: taxAccount.id,
              debit: Value(purchase.tax),
              credit: Value(Decimal.zero),
              currencyId: Value(purchase.currencyId),
              exchangeRate: Value(purchase.exchangeRate),
              branchId: Value(purchase.branchId ??
                  await _configService.getDefaultBranchId()),
            ),
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: creditAccountId,
            debit: Value(Decimal.zero),
            credit: Value(purchase.total),
            currencyId: Value(purchase.currencyId),
            exchangeRate: Value(purchase.exchangeRate),
            branchId: Value(
                purchase.branchId ?? await _configService.getDefaultBranchId()),
          ),
        ];

        await dao.createEntry(entry, lines);

        if (purchase.isCredit) {
          await _recordAccountTransaction(
            accountId: creditAccountId,
            type: 'INVOICE',
            referenceId: purchase.id,
            credit: purchase.total,
            date: purchase.date,
            branchId:
                purchase.branchId ?? await _configService.getDefaultBranchId(),
          );
        }

        await _auditService.logCreate(
          'GLEntry',
          entryId,
          details:
              'Purchase entry for Purchase #${purchase.id.substring(0, 8)}',
        );
      });
    } catch (e) {
      throw Exception('Failed to post purchase: ${e.toString()}');
    }
  }

  Future<void> recordCustomerPayment({
    required String customerId,
    required Decimal amount,
    required String paymentAccountCode,
    required String currencyId,
    required Decimal exchangeRate,
  }) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final arAccount = await dao.getAccountByCode(codeAccountsReceivable);
    final paymentAccount = await dao.getAccountByCode(paymentAccountCode);

    if (arAccount == null || paymentAccount == null) {
      throw Exception('AR or Payment account not found.');
    }

    final customer = await db.customersDao.getCustomerById(customerId);

    final defaultBranchId = await _configService.getDefaultBranchId();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Payment from ${customer?.name ?? "Customer"}',
      date: Value(DateTime.now()),
      referenceType: const Value('CUSTOMER_PAYMENT'),
      referenceId: Value(customerId),
      currencyId: Value(currencyId),
      exchangeRate: Value(exchangeRate),
      branchId: Value(defaultBranchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: paymentAccount.id,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        currencyId: Value(currencyId),
        exchangeRate: Value(exchangeRate),
        branchId: Value(defaultBranchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: arAccount.id,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        currencyId: Value(currencyId),
        exchangeRate: Value(exchangeRate),
        branchId: Value(defaultBranchId),
      ),
    ];

    await dao.createEntry(entry, lines);
  }

  Future<void> recordPaymentToSupplier({
    required String supplierId,
    required Decimal amount,
    required String paymentAccountCode,
    required String currencyId,
    required Decimal exchangeRate,
  }) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final apAccount = await dao.getAccountByCode(codeAccountsPayable);
    final paymentAccount = await dao.getAccountByCode(paymentAccountCode);

    if (apAccount == null || paymentAccount == null) {
      throw Exception('AP or Payment account not found.');
    }

    final defaultBranchId = await _configService.getDefaultBranchId();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Payment to Supplier',
      date: Value(DateTime.now()),
      referenceType: const Value('SUPPLIER_PAYMENT'),
      referenceId: Value(supplierId),
      currencyId: Value(currencyId),
      exchangeRate: Value(exchangeRate),
      branchId: Value(defaultBranchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: apAccount.id,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        currencyId: Value(currencyId),
        exchangeRate: Value(exchangeRate),
        branchId: Value(defaultBranchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: paymentAccount.id,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        currencyId: Value(currencyId),
        exchangeRate: Value(exchangeRate),
        branchId: Value(defaultBranchId),
      ),
    ];

    await dao.createEntry(entry, lines);

    await _auditService.logCreate(
      'GLEntry',
      entryId,
      details: 'Payment to Supplier: $supplierId, Amount: $amount',
    );
  }

  Future<void> recordCheckCollected(Check check) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    GLAccount? primaryAccount;
    GLAccount? secondaryAccount;
    Decimal amount = Decimal.parse(check.amount.toString());
    String description;

    if (check.type == 'RECEIVED') {
      primaryAccount = await dao.getAccountByCode(codeAccountsReceivable);
      secondaryAccount = await dao.getAccountByCode(
        check.paymentAccountId ?? 'UNKNOWN',
      );
      description = 'Collection of Check #${check.checkNumber}';
    } else {
      primaryAccount = await dao.getAccountByCode(codeAccountsPayable);
      secondaryAccount = await dao.getAccountByCode(
        check.paymentAccountId ?? 'UNKNOWN',
      );
      description = 'Payment via Check #${check.checkNumber}';
    }

    if (primaryAccount == null || secondaryAccount == null) {
      throw Exception('Required GL accounts not found.');
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: description,
      date: Value(DateTime.now()),
      referenceType: const Value('CHECK_COLLECTED'),
      referenceId: Value(check.id),
      currencyId: Value(check.currencyId),
      exchangeRate: Value(check.exchangeRate),
      branchId: Value(await _configService.getDefaultBranchId()),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: primaryAccount.id,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        currencyId: Value(check.currencyId),
        exchangeRate: Value(check.exchangeRate),
        branchId: Value(await _configService.getDefaultBranchId()),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: secondaryAccount.id,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        currencyId: Value(check.currencyId),
        exchangeRate: Value(check.exchangeRate),
        branchId: Value(await _configService.getDefaultBranchId()),
      ),
    ];
    await dao.createEntry(entry, lines);
  }

  Future<void> recordCheckBounced(Check check) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    GLAccount? primaryAccount;
    GLAccount? secondaryAccount;
    Decimal amount = Decimal.parse(check.amount.toString());
    String description;

    if (check.type == 'RECEIVED') {
      primaryAccount = await dao.getAccountByCode(codeAccountsReceivable);
      secondaryAccount = await dao.getAccountByCode(
        check.paymentAccountId ?? 'UNKNOWN',
      );
      description = 'Bounced Check #${check.checkNumber}';
    } else {
      primaryAccount = await dao.getAccountByCode(codeAccountsPayable);
      secondaryAccount = await dao.getAccountByCode(
        check.paymentAccountId ?? 'UNKNOWN',
      );
      description = 'Bounced Check #${check.checkNumber}';
    }

    if (primaryAccount == null || secondaryAccount == null) {
      throw Exception('Required GL accounts not found.');
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: description,
      date: Value(DateTime.now()),
      referenceType: const Value('CHECK_BOUNCED'),
      referenceId: Value(check.id),
      currencyId: Value(check.currencyId),
      exchangeRate: Value(check.exchangeRate),
      branchId: Value(await _configService.getDefaultBranchId()),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: primaryAccount.id,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        currencyId: Value(check.currencyId),
        exchangeRate: Value(check.exchangeRate),
        branchId: Value(await _configService.getDefaultBranchId()),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: secondaryAccount.id,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        currencyId: Value(check.currencyId),
        exchangeRate: Value(check.exchangeRate),
        branchId: Value(await _configService.getDefaultBranchId()),
      ),
    ];
    await dao.createEntry(entry, lines);
  }

  Future<void> postSaleReturn(
    SalesReturn saleReturn,
    List<SalesReturnItem> items,
    String userId,
  ) async {
    await _permissionService
        .executeIfAllowed(userId, PermissionCode.postSaleReturn, () async {
      final dao = db.accountingDao;
      final originalSale = await db.salesDao.getSaleById(saleReturn.saleId);
      if (originalSale == null) throw Exception('Original sale not found.');

      final entryId = const Uuid().v4();
      final salesReturnAccount = await dao.getAccountByCode(codeSalesReturns);
      final taxAccount = await dao.getAccountByCode(codeOutputVAT);
      final arAccount = await dao.getAccountByCode(codeAccountsReceivable);
      final cashAccount = await dao.getAccountByCode(codeCash);

      if (salesReturnAccount == null ||
          taxAccount == null ||
          arAccount == null ||
          cashAccount == null) {
        throw Exception('Missing accounts for sale return.');
      }

      final Decimal totalReturned = Decimal.parse(saleReturn.amountReturned.toString());
      final Decimal originalTotal = originalSale.total;
      final Decimal originalTax = originalSale.tax;
      
      final Decimal taxPortion = originalTax > Decimal.zero
          ? Decimal.parse((totalReturned / originalTotal).toString()) * originalTax
          : Decimal.zero;
      final Decimal revenuePortion = totalReturned - taxPortion;
      final creditAccount = originalSale.isCredit ? arAccount : cashAccount;

      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description: 'Sale Return for Sale #${originalSale.id.substring(0, 8)}',
        date: Value(saleReturn.createdAt),
        referenceType: const Value('SALE_RETURN'),
        referenceId: Value(saleReturn.id),
        branchId: Value(
            originalSale.branchId ?? await _configService.getDefaultBranchId()),
      );

      final lines = [
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: salesReturnAccount.id,
          debit: Value(revenuePortion),
          credit: Value(Decimal.zero),
          branchId: Value(originalSale.branchId ??
              await _configService.getDefaultBranchId()),
        ),
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: taxAccount.id,
          debit: Value(taxPortion),
          credit: Value(Decimal.zero),
          branchId: Value(originalSale.branchId ??
              await _configService.getDefaultBranchId()),
        ),
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: creditAccount.id,
          debit: Value(Decimal.zero),
          credit: Value(totalReturned),
          branchId: Value(originalSale.branchId ??
              await _configService.getDefaultBranchId()),
        ),
      ];

      await dao.createEntry(entry, lines);

      if (originalSale.isCredit) {
        await _recordAccountTransaction(
          accountId: creditAccount.id,
          type: 'RETURN',
          referenceId: saleReturn.id,
          credit: totalReturned,
          date: saleReturn.createdAt,
          branchId: originalSale.branchId ??
              await _configService.getDefaultBranchId(),
        );
      }

      Decimal totalCostReversed = Decimal.zero;
      for (var item in items) {
        final batches = await (db.select(db.productBatches)
              ..where((b) => b.productId.equals(item.productId))
              ..where((b) => b.quantity.isBiggerThan(Constant(Decimal.zero.toString())))
              ..orderBy([
                (b) => OrderingTerm(
                      expression: b.expiryDate.isNull(),
                      mode: OrderingMode.asc,
                    ),
                (b) => OrderingTerm(
                      expression: b.expiryDate,
                      mode: OrderingMode.asc,
                    ),
                (b) => OrderingTerm(
                      expression: b.createdAt,
                      mode: OrderingMode.asc,
                    ),
              ]))
            .get();

        Decimal remainingQty = Decimal.parse(item.quantity.toString());
        for (var batch in batches) {
          if (remainingQty <= Decimal.zero) break;
          Decimal deductFromBatch =
              batch.quantity >= remainingQty ? remainingQty : batch.quantity;
          totalCostReversed += deductFromBatch * batch.costPrice;
          remainingQty -= deductFromBatch;
        }
      }

      if (totalCostReversed > Decimal.zero) {
        final cogsEntryId = const Uuid().v4();
        final cogsAccount = await dao.getAccountByCode(codeCOGS);
        final inventoryAccount = await dao.getAccountByCode(codeInventory);
        if (cogsAccount != null && inventoryAccount != null) {
          final cogsEntry = GLEntriesCompanion.insert(
            id: Value(cogsEntryId),
            description:
                'COGS Reversal for Sale Return #${saleReturn.id.substring(0, 8)}',
            date: Value(saleReturn.createdAt),
            referenceType: const Value('COGS_REVERSAL'),
            referenceId: Value(saleReturn.id),
            branchId: Value(originalSale.branchId ??
                await _configService.getDefaultBranchId()),
          );
          final cogsLines = [
            GLLinesCompanion.insert(
              entryId: cogsEntryId,
              accountId: inventoryAccount.id,
              debit: Value(totalCostReversed),
              credit: Value(Decimal.zero),
              branchId: Value(originalSale.branchId ??
                  await _configService.getDefaultBranchId()),
            ),
            GLLinesCompanion.insert(
              entryId: cogsEntryId,
              accountId: cogsAccount.id,
              debit: Value(Decimal.zero),
              credit: Value(totalCostReversed),
              branchId: Value(originalSale.branchId ??
                  await _configService.getDefaultBranchId()),
            ),
          ];
          await dao.createEntry(cogsEntry, cogsLines);
        }
      }
    });
  }

  Future<void> postPurchaseReturn(
    PurchaseReturn purchaseReturn,
    List<PurchaseReturnItem> items,
    String userId,
  ) async {
    await _permissionService
        .executeIfAllowed(userId, PermissionCode.postPurchaseReturn, () async {
      final dao = db.accountingDao;
      final originalPurchase = await db.purchasesDao.getPurchaseById(
        purchaseReturn.purchaseId,
      );
      if (originalPurchase == null) {
        throw Exception('Original purchase not found.');
      }

      final entryId = const Uuid().v4();
      final purchaseReturnAccount = await dao.getAccountByCode(
        codePurchaseReturns,
      );
      final taxAccount = await dao.getAccountByCode(codeInputVAT);
      final apAccount = await dao.getAccountByCode(codeAccountsPayable);
      final cashAccount = await dao.getAccountByCode(codeCash);

      if (purchaseReturnAccount == null ||
          taxAccount == null ||
          apAccount == null ||
          cashAccount == null) {
        throw Exception('Missing accounts for purchase return.');
      }

      final Decimal totalReturned = Decimal.parse(purchaseReturn.amountReturned.toString());
      final Decimal originalTotal = originalPurchase.total;
      final Decimal originalTax = originalPurchase.tax;
      
      final Decimal taxPortion = originalTax > Decimal.zero
          ? Decimal.parse((totalReturned / originalTotal).toString()) * originalTax
          : Decimal.zero;
      final Decimal purchasePortion = totalReturned - taxPortion;
      final debitAccount = originalPurchase.isCredit ? apAccount : cashAccount;

      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description:
            'Purchase Return for Purchase #${originalPurchase.id.substring(0, 8)}',
        date: Value(purchaseReturn.createdAt),
        referenceType: const Value('PURCHASE_RETURN'),
        referenceId: Value(purchaseReturn.id),
        branchId: Value(originalPurchase.branchId ??
            await _configService.getDefaultBranchId()),
      );

      final lines = [
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: debitAccount.id,
          debit: Value(totalReturned),
          credit: Value(Decimal.zero),
          branchId: Value(originalPurchase.branchId ??
              await _configService.getDefaultBranchId()),
        ),
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: purchaseReturnAccount.id,
          debit: Value(Decimal.zero),
          credit: Value(purchasePortion),
          branchId: Value(originalPurchase.branchId ??
              await _configService.getDefaultBranchId()),
        ),
        if (taxPortion > Decimal.zero)
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: taxAccount.id,
            debit: Value(Decimal.zero),
            credit: Value(taxPortion),
            branchId: Value(originalPurchase.branchId ??
                await _configService.getDefaultBranchId()),
          ),
      ];

      await dao.createEntry(entry, lines);

      if (originalPurchase.isCredit) {
        final supplier = await db.suppliersDao.getSupplierById(
          originalPurchase.supplierId!,
        );
        final supplierAccountId = supplier?.accountId ?? apAccount.id;

        await _recordAccountTransaction(
          accountId: supplierAccountId,
          type: 'RETURN',
          referenceId: purchaseReturn.id,
          debit: totalReturned,
          date: purchaseReturn.createdAt,
          branchId: originalPurchase.branchId ??
              await _configService.getDefaultBranchId(),
        );
      }
    });
  }

  Future<void> runAutomaticDepreciation(DateTime asOfDate) async {
    final dao = db.accountingDao;
    final assets = await db.select(db.fixedAssets).get();
    final depreciationAccount = await dao.getAccountByCode(
      codeDepreciationExpense,
    );
    final accumulatedDepAccount = await dao.getAccountByCode(
      codeAccumulatedDepreciation,
    );

    if (depreciationAccount == null || accumulatedDepAccount == null) return;

    for (var asset in assets) {
      double monthlyDepreciation =
          (asset.cost - asset.salvageValue) / (asset.usefulLifeYears * 12);

      int totalMonths = asset.usefulLifeYears * 12;
      double alreadyDepreciatedMonths =
          asset.accumulatedDepreciation / monthlyDepreciation;

      final elapsedDuration = asOfDate.difference(asset.purchaseDate);
      int elapsedMonths = (elapsedDuration.inDays / 30).floor();

      int monthsToDepreciate = elapsedMonths - alreadyDepreciatedMonths.floor();
      if (monthsToDepreciate <= 0) continue;

      if (alreadyDepreciatedMonths + monthsToDepreciate > totalMonths) {
        monthsToDepreciate = (totalMonths - alreadyDepreciatedMonths).floor();
      }

      if (monthsToDepreciate <= 0) continue;

      double depreciationAmount = monthsToDepreciate * monthlyDepreciation;
      final Decimal depAmountDecimal = Decimal.parse(depreciationAmount.toString());
      final entryId = const Uuid().v4();

      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description:
            'إهلاك تلقائي للأصل: ${asset.name} لمدة $monthsToDepreciate شهر',
        date: Value(asOfDate),
        referenceType: const Value('DEPRECIATION'),
        referenceId: Value(asset.id.toString()),
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
        branchId: Value(await _configService.getDefaultBranchId()),
      );

      final lines = [
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: depreciationAccount.id,
          debit: Value(depAmountDecimal),
          credit: Value(Decimal.zero),
          branchId: Value(await _configService.getDefaultBranchId()),
        ),
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: accumulatedDepAccount.id,
          debit: Value(Decimal.zero),
          credit: Value(depAmountDecimal),
          branchId: Value(await _configService.getDefaultBranchId()),
        ),
      ];

      await dao.createEntry(entry, lines);

      await (db.update(
        db.fixedAssets,
      )..where((a) => a.id.equals(asset.id)))
          .write(
        FixedAssetsCompanion(
          accumulatedDepreciation: Value(
            asset.accumulatedDepreciation + depreciationAmount,
          ),
        ),
      );
    }
  }

  Future<VatReportData> getVatReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dao = db.accountingDao;
    final reportStartDate = startDate ?? DateTime(2000);
    final reportEndDate = endDate ?? DateTime.now();
    final outputVatAccount = await dao.getAccountByCode(codeOutputVAT);
    final inputVatAccount = await dao.getAccountByCode(codeInputVAT);

    if (outputVatAccount == null || inputVatAccount == null) {
      throw Exception('Output VAT or Input VAT accounts not found.');
    }

    final outputVatLines = await (db.select(db.gLLines).join([
      innerJoin(
        db.gLEntries,
        db.gLEntries.id.equalsExp(db.gLLines.entryId),
      ),
    ])
          ..where(
            db.gLLines.accountId.equals(outputVatAccount.id) &
                db.gLEntries.date.isBetweenValues(
                  reportStartDate,
                  reportEndDate,
                ),
          ))
        .get();

    Decimal totalOutputVat = Decimal.zero;
    for (final line in outputVatLines) {
      totalOutputVat += ((line.read(db.gLLines.credit) as Decimal?) ?? Decimal.zero) -
          ((line.read(db.gLLines.debit) as Decimal?) ?? Decimal.zero);
    }

    final inputVatLines = await (db.select(db.gLLines).join([
      innerJoin(
        db.gLEntries,
        db.gLEntries.id.equalsExp(db.gLLines.entryId),
      ),
    ])
          ..where(
            db.gLLines.accountId.equals(inputVatAccount.id) &
                db.gLEntries.date.isBetweenValues(
                  reportStartDate,
                  reportEndDate,
                ),
          ))
        .get();

    Decimal totalInputVat = Decimal.zero;
    for (final line in inputVatLines) {
      totalInputVat += ((line.read(db.gLLines.debit) as Decimal?) ?? Decimal.zero) -
          ((line.read(db.gLLines.credit) as Decimal?) ?? Decimal.zero);
    }

    final taxableSales = await (db.select(db.sales)
          ..where((s) =>
              s.tax.isBiggerThan(Constant(Decimal.zero.toString())) &
              s.updatedAt.isBetweenValues(reportStartDate, reportEndDate)))
        .get();
    Decimal totalTaxableSales =
        taxableSales.fold(Decimal.zero, (sum, s) => sum + (s.total - s.tax));

    final taxablePurchases = await (db.select(db.purchases)
          ..where((p) =>
              p.tax.isBiggerThan(Constant(Decimal.zero.toString())) &
              p.updatedAt.isBetweenValues(reportStartDate, reportEndDate)))
        .get();
    Decimal totalTaxablePurchases =
        taxablePurchases.fold(Decimal.zero, (sum, p) => sum + (p.total - p.tax));

    return VatReportData(
      totalTaxableSales: totalTaxableSales,
      totalOutputVat: totalOutputVat,
      totalTaxablePurchases: totalTaxablePurchases,
      totalInputVat: totalInputVat,
      netVatPayable: totalOutputVat - totalInputVat,
      startDate: reportStartDate,
      endDate: reportEndDate,
    );
  }

  Future<void> generateOpeningBalances({
    required int newFiscalYear,
    required String userId,
  }) async {
    final dao = db.accountingDao;
    final previousYear = newFiscalYear - 1;

    final prevYearPeriod = await (db.select(db.accountingPeriods)
          ..where((p) => p.fiscalYear.equals(previousYear))
          ..orderBy([(t) => OrderingTerm(expression: t.endDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();

    if (prevYearPeriod == null) {
      throw Exception('Previous fiscal year $previousYear not found or not closed.');
    }

    final allAccounts = await dao.getAllAccounts();
    final balanceSheetAccounts = allAccounts.where((a) => 
        a.type == AccountType.asset || 
        a.type == AccountType.liability || 
        a.type == AccountType.equity
    );

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'أرصدة افتتاحية للسنة المالية $newFiscalYear',
      date: Value(DateTime(newFiscalYear, 1, 1)),
      referenceType: const Value('OPENING_BALANCE'),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(await _configService.getDefaultBranchId()),
    );

    List<GLLinesCompanion> lines = [];

    for (var acc in balanceSheetAccounts) {
      final Decimal balance = Decimal.parse((await dao.getAccountBalanceAsOfDate(acc.id, prevYearPeriod.endDate)).toString());
      
      if (balance == Decimal.zero) continue;

      if (acc.type == AccountType.asset) {
        if (balance > Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(balance),
            credit: Value(Decimal.zero),
            memo: const Value('Opening Balance'),
            branchId: Value(await _configService.getDefaultBranchId()),
          ));
        } else if (balance < Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(Decimal.zero),
            credit: Value(balance.abs()),
            memo: const Value('Opening Balance'),
            branchId: Value(await _configService.getDefaultBranchId()),
          ));
        }
      } else {
        if (balance > Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(Decimal.zero),
            credit: Value(balance),
            memo: const Value('Opening Balance'),
            branchId: Value(await _configService.getDefaultBranchId()),
          ));
        } else if (balance < Decimal.zero) {
          lines.add(GLLinesCompanion.insert(
            entryId: entryId,
            accountId: acc.id,
            debit: Value(balance.abs()),
            credit: Value(Decimal.zero),
            memo: const Value('Opening Balance'),
            branchId: Value(await _configService.getDefaultBranchId()),
          ));
        }
      }
    }

    if (lines.isNotEmpty) {
      await dao.createEntry(entry, lines);
    }
  }


  Future<IncomeStatementData> getIncomeStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dao = db.accountingDao;
    final allAccounts = await dao.getAllAccounts();
    final revenueAccounts = allAccounts.where((acc) => acc.type == 'REVENUE');
    final expenseAccounts = allAccounts.where((acc) => acc.type == 'EXPENSE');

    final List<TrialBalanceItem> revenues = [];
    for (var account in revenueAccounts) {
      final balance = startDate != null 
        ? await dao.getAccountBalanceInRange(account.id, startDate, endDate ?? DateTime.now())
        : await dao.getAccountBalanceAsOfDate(account.id, endDate ?? DateTime.now());
      revenues.add(TrialBalanceItem(account, 0.0, balance.toDouble()));
    }

    final List<TrialBalanceItem> expenses = [];
    for (var account in expenseAccounts) {
      final balance = startDate != null
        ? await dao.getAccountBalanceInRange(account.id, startDate, endDate ?? DateTime.now())
        : await dao.getAccountBalanceAsOfDate(account.id, endDate ?? DateTime.now());
      expenses.add(TrialBalanceItem(account, balance.toDouble(), 0.0));
    }

    double totalRevenue = revenues.fold(
      0.0,
      (sum, item) => sum + item.totalCredit,
    );
    double totalExpense = expenses.fold(
      0.0,
      (sum, item) => sum + item.totalDebit,
    );

    return IncomeStatementData(
      revenues: revenues,
      expenses: expenses,
      totalRevenue: totalRevenue,
      totalExpense: totalExpense,
      netIncome: totalRevenue - totalExpense,
      startDate: startDate,
      endDate: endDate ?? DateTime.now(),
    );
  }

  Future<Map<String, IncomeStatementData>> compareIncomeStatement({
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
  }) async {
    final data1 = await getIncomeStatement(startDate: period1Start, endDate: period1End);
    final data2 = await getIncomeStatement(startDate: period2Start, endDate: period2End);
    return {
      'period1': data1,
      'period2': data2,
    };
  }


  Future<BalanceSheetData> getBalanceSheet({DateTime? date}) async {
    final dao = db.accountingDao;
    final asOfDate = date ?? DateTime.now();
    final allAccounts = await dao.getAllAccounts();

    final List<BalanceSheetItem> assets = [];
    for (var account in allAccounts.where((acc) => acc.type == 'ASSET')) {
      if (!account.isHeader) {
        final balance = await dao.getAccountBalanceAsOfDate(
          account.id,
          asOfDate,
        );
        assets.add(BalanceSheetItem(account, balance.toDouble()));
      }
    }

    final List<BalanceSheetItem> liabilities = [];
    for (var account in allAccounts.where((acc) => acc.type == 'LIABILITY')) {
      if (!account.isHeader) {
        final balance = await dao.getAccountBalanceAsOfDate(
          account.id,
          asOfDate,
        );
        liabilities.add(BalanceSheetItem(account, balance.toDouble()));
      }
    }

    final List<BalanceSheetItem> equity = [];
    for (var account in allAccounts.where((acc) => acc.type == 'EQUITY')) {
      if (!account.isHeader) {
        final balance = await dao.getAccountBalanceAsOfDate(
          account.id,
          asOfDate,
        );
        equity.add(BalanceSheetItem(account, balance.toDouble()));
      }
    }

    double totalAssets = assets.fold(0.0, (sum, item) => sum + item.balance);
    double totalLiabilities = liabilities.fold(
      0.0,
      (sum, item) => sum + item.balance,
    );
    double totalEquity = equity.fold(0.0, (sum, item) => sum + item.balance);

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

  Future<void> createRevaluationEntry(dynamic invoice, String reason) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();
    final branchId = await _configService.getDefaultBranchId();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'إعادة تقييم: $reason (المرجع: ${invoice.id})',
      date: Value(DateTime.now()),
      referenceType: const Value('REVALUATION'),
      referenceId: Value(invoice.id),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: (await dao.getAccountByCode(codeRetainedEarnings))?.id ?? 'retained_earnings',
        debit: Value(Decimal.zero),
        credit: Value(Decimal.zero),
        memo: Value('Adjustment for invoice ${invoice.id}'),
        branchId: Value(branchId),
      ),
    ];

    await db.transaction(() async {
      await dao.createEntry(entry, lines);
      await _auditService.logCreate('GLEntry', entryId, details: 'Revaluation for invoice ${invoice.id}: $reason');
    });
  }

  Future<void> closeFinancialYear(DateTime date) async {
    final fiscalYear = date.year;
    
    await db.transaction(() async {
      await (db.update(db.accountingPeriods)..where((p) => p.fiscalYear.equals(fiscalYear)))
          .write(const AccountingPeriodsCompanion(isClosed: Value(true), status: Value('CLOSED')));
      
      await generateOpeningBalances(newFiscalYear: fiscalYear + 1, userId: 'SYSTEM');
    });
  }

  Future<void> recordExpense({
    required String description,
    required Decimal amount,
    required DateTime date,
    required String expenseAccountId,
    required String paymentAccountId,
    String? costCenterId,
  }) async {
    final dao = db.accountingDao;
    final budgetService = sl<BudgetService>();
    final period = '${date.year}-${date.month}';

    if (costCenterId != null) {
      await budgetService.validateExpenseAgainstBudget(
        costCenterId: costCenterId,
        expenseAmount: amount.toDouble(),
        period: period,
      );
    }

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: description,
      date: Value(date),
      referenceType: const Value('EXPENSE'),
      branchId: Value(await _configService.getDefaultBranchId()),
    );
    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: expenseAccountId,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        costCenterId: Value(costCenterId),
        branchId: Value(await _configService.getDefaultBranchId()),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: paymentAccountId,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        costCenterId: Value(costCenterId),
        branchId: Value(await _configService.getDefaultBranchId()),
      ),
    ];
    await dao.createEntry(entry, lines);

    if (costCenterId != null) {
      await budgetService.updateActualBudget(
        costCenterId: costCenterId,
        expenseAmount: amount.toDouble(),
        period: period,
      );
    }
    
    await _auditService.logCreate('EXPENSE', entryId, details: description);
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

    final cashAccounts = await dao.getAccountsByType('ASSET');
    final cashAccountIds = cashAccounts
        .where((acc) => acc.code == codeCash || acc.code == codeBank)
        .map((acc) => acc.id)
        .toSet();

    Decimal beginningCashBalance = Decimal.zero;
    if (reportStartDate != DateTime(2000)) {
      for (var cashAccountId in cashAccountIds) {
        beginningCashBalance += Decimal.parse((await dao.getAccountBalanceAsOfDate(
          cashAccountId,
          reportStartDate.subtract(const Duration(milliseconds: 1)),
        )).toString());
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
                codeAccountsReceivable,
                codeAccountsPayable,
                codeInputVAT,
                codeOutputVAT,
              ].contains(line.account.code)) {
            operatingActivities += cashMovement;
            categorized = true;
            break;
          } else if (line.account.code == codeFixedAssets) {
            investingActivities += cashMovement;
            categorized = true;
            break;
          } else if ([
            codeLoansPayable,
            codeCapital,
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
      operatingActivities: operatingActivities.toDouble(),
      investingActivities: investingActivities.toDouble(),
      financingActivities: financingActivities.toDouble(),
      netCashFlow: netCashFlow.toDouble(),
      beginningCashBalance: beginningCashBalance.toDouble(),
      endingCashBalance: (beginningCashBalance + netCashFlow).toDouble(),
      startDate: reportStartDate,
      endDate: reportEndDate,
    );
  }
}
