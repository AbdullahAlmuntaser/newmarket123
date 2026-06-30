import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:uuid/uuid.dart';
import 'audit_service.dart';
import 'event_bus_service.dart';
import 'package:json_annotation/json_annotation.dart';
import 'dart:async';
import 'app_config_service.dart';
import 'budget_service.dart';
import 'package:supermarket/injection_container.dart';

part 'accounting_service.g.dart';

@JsonSerializable(explicitToJson: true)
class AccountingDashboardData {
  final Decimal totalRevenue;
  final Decimal totalExpenses;
  final Decimal netIncome;
  final Decimal totalAssets;
  final Decimal totalLiabilities;
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
  final Decimal quantity;
  DashboardTopProduct(this.productName, this.quantity);

  factory DashboardTopProduct.fromJson(Map<String, dynamic> json) =>
      _$DashboardTopProductFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardTopProductToJson(this);
}

@JsonSerializable()
class DailyValue {
  final DateTime date;
  final Decimal value;
  DailyValue(this.date, this.value);

  factory DailyValue.fromJson(Map<String, dynamic> json) =>
      _$DailyValueFromJson(json);
  Map<String, dynamic> toJson() => _$DailyValueToJson(this);
}

@JsonSerializable()
class CashFlowData {
  final Decimal operatingActivities;
  final Decimal investingActivities;
  final Decimal financingActivities;
  final Decimal netCashFlow;
  final Decimal beginningCashBalance;
  final Decimal endingCashBalance;
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
  final Decimal grossProfitMargin;
  final Decimal netProfitMargin;
  final Decimal currentRatio;

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
  final Decimal totalRevenue;
  final Decimal totalExpense;
  final Decimal netIncome;
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
  final Decimal totalAssets;
  final Decimal totalLiabilities;
  final Decimal totalEquity;
  final Decimal netIncome;
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
  final Decimal balance;

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

/// AccountingService is now a pure reporting/query service.
/// All GL entry creation is handled by TransactionEngine through PostingEngine.
class AccountingService {
  final AppDatabase db;
  final EventBusService eventBus;
  late final AuditService _auditService;
  late final AppConfigService _configService;

  AccountingService(this.db, this.eventBus) {
    _auditService = AuditService(db);
    _configService = AppConfigService(db);
  }

  Future<void> dispose() async {}

  /// All posting operations are now handled by TransactionEngine through PostingEngine.
  /// These methods are kept as stubs for backward compatibility only.

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

    final allBalances = await dao.getAllAccountBalancesAsOfDate(asOfDate);
    final Map<String, Decimal> balanceByCode = {};
    for (final item in allBalances) {
      balanceByCode[item.account.code] = item.netBalance;
    }

    final Decimal totalRevenue = incomeStatement.totalRevenue;
    final Decimal totalCogs = balanceByCode[codeCOGS] ?? Decimal.zero;
    final Decimal grossProfit = totalRevenue - totalCogs;
    final Decimal grossProfitMargin = totalRevenue > Decimal.zero
        ? (grossProfit / totalRevenue).toDecimal()
        : Decimal.zero;
    final Decimal netProfitMargin = totalRevenue > Decimal.zero
        ? (incomeStatement.netIncome / totalRevenue).toDecimal()
        : Decimal.zero;

    final Decimal totalCurrentAssets =
        (balanceByCode[codeCash] ?? Decimal.zero) +
            (balanceByCode[codeBank] ?? Decimal.zero) +
            (balanceByCode[codeAccountsReceivable] ?? Decimal.zero) +
            (balanceByCode[codeInventory] ?? Decimal.zero);

    final Decimal totalCurrentLiabilities =
        (balanceByCode[codeAccountsPayable] ?? Decimal.zero) +
            (balanceByCode[codeOutputVAT] ?? Decimal.zero);

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
    final endDate = last7Days.add(const Duration(days: 7));

    final allRows = await (db.select(db.gLLines).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
      innerJoin(
          db.gLAccounts, db.gLAccounts.id.equalsExp(db.gLLines.accountId)),
    ])
          ..where(db.gLAccounts.type.isIn(['REVENUE', 'EXPENSE']) &
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

    final topProductsFromDao = await db.salesDao.getTopSellingProducts(
      limit: 5,
    );
    final topSellingProducts = topProductsFromDao
        .map((p) => DashboardTopProduct(
            p.product.name, Decimal.parse(p.totalQuantity.toString())))
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
    final parent = await dao.getAccountByCode(codeAccountsReceivable);
    if (parent == null) {
      throw Exception(
          'حساب الذمم المدينة الرئيسي ($codeAccountsReceivable) غير موجود. يجب إنشاءه أولاً من شجرة الحسابات.');
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
      throw Exception(
          'حساب الذمم الدائنة الرئيسي غير موجود. تعذر إنشاء حساب المورد.');
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
      final costDecimal = Decimal.parse(asset.cost.toString());
      final salvageDecimal = Decimal.parse(asset.salvageValue.toString());
      final usefulLifeMonths = asset.usefulLifeYears * 12;
      final monthlyDepreciation =
          ((costDecimal - salvageDecimal) / Decimal.fromInt(usefulLifeMonths))
              .toDecimal(scaleOnInfinitePrecision: 3);

      final totalMonths = usefulLifeMonths;
      final accDepDecimal =
          Decimal.parse(asset.accumulatedDepreciation.toString());
      final alreadyDepreciatedMonths = accDepDecimal > Decimal.zero
          ? (accDepDecimal / monthlyDepreciation)
              .toDecimal(scaleOnInfinitePrecision: 0)
          : Decimal.zero;

      final elapsedDuration = asOfDate.difference(asset.purchaseDate);
      final elapsedMonths =
          Decimal.fromInt((elapsedDuration.inDays / 30).floor());

      var monthsToDepreciate = elapsedMonths - alreadyDepreciatedMonths;
      if (monthsToDepreciate <= Decimal.zero) continue;

      if (alreadyDepreciatedMonths + monthsToDepreciate >
          Decimal.fromInt(totalMonths)) {
        monthsToDepreciate =
            Decimal.fromInt(totalMonths) - alreadyDepreciatedMonths;
      }

      if (monthsToDepreciate <= Decimal.zero) continue;

      final depAmountDecimal = monthlyDepreciation * monthsToDepreciate;
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
            accDepDecimal + depAmountDecimal,
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
      totalOutputVat +=
          ((line.read(db.gLLines.credit) as Decimal?) ?? Decimal.zero) -
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
      totalInputVat +=
          ((line.read(db.gLLines.debit) as Decimal?) ?? Decimal.zero) -
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
    Decimal totalTaxablePurchases = taxablePurchases.fold(
        Decimal.zero, (sum, p) => sum + (p.total - p.tax));

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
          ..orderBy([
            (t) => OrderingTerm(expression: t.endDate, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();

    if (prevYearPeriod == null) {
      throw Exception(
          'Previous fiscal year $previousYear not found or not closed.');
    }

    final allAccounts = await dao.getAllAccounts();
    final balanceSheetAccounts = allAccounts.where((a) =>
        a.type == AccountType.asset ||
        a.type == AccountType.liability ||
        a.type == AccountType.equity);

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
      final Decimal balance = Decimal.parse(
          (await dao.getAccountBalanceAsOfDate(acc.id, prevYearPeriod.endDate))
              .toString());

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
    final allBalances = await dao.getAllAccountBalancesAsOfDate(asOfDate);

    final List<BalanceSheetItem> assets = [];
    final List<BalanceSheetItem> liabilities = [];
    final List<BalanceSheetItem> equity = [];

    for (final item in allBalances) {
      if (item.account.isHeader) continue;
      final balance = item.netBalance;
      if (item.account.type == 'ASSET') {
        assets.add(BalanceSheetItem(item.account, balance));
      } else if (item.account.type == 'LIABILITY') {
        liabilities.add(BalanceSheetItem(item.account, balance));
      } else if (item.account.type == 'EQUITY') {
        equity.add(BalanceSheetItem(item.account, balance));
      }
    }

    Decimal totalAssets =
        assets.fold(Decimal.zero, (sum, item) => sum + item.balance);
    Decimal totalLiabilities = liabilities.fold(
      Decimal.zero,
      (sum, item) => sum + item.balance,
    );
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

  /// Creates a balanced double-entry revaluation posting.
  /// [invoice] must expose: .id, .assetId, .previousValue, .newValue
  /// or a custom revaluation with explicit [debitAccountId], [creditAccountId], [amount].
  Future<void> createRevaluationEntry(
    dynamic invoice,
    String reason, {
    String? debitAccountId,
    String? creditAccountId,
    Decimal? amount,
  }) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();
    final branchId = await _configService.getDefaultBranchId();

    Decimal revalAmount;
    String actualDebitAccountId;
    String actualCreditAccountId;

    if (amount != null && debitAccountId != null && creditAccountId != null) {
      // Explicit revaluation — caller provides everything
      revalAmount = amount;
      actualDebitAccountId = debitAccountId;
      actualCreditAccountId = creditAccountId;
    } else {
      // Automatic revaluation: compute difference from invoice fields
      final previousValue =
          Decimal.tryParse('${invoice.previousValue}') ?? Decimal.zero;
      final newValue = Decimal.tryParse('${invoice.newValue}') ?? Decimal.zero;
      revalAmount = (newValue - previousValue).abs();

      if (revalAmount <= Decimal.zero) {
        throw Exception('لا يوجد فرق في القيمة لإعادة التقييم.');
      }

      if (newValue > previousValue) {
        // Increase: Debit asset, Credit revaluation surplus (retained earnings)
        actualDebitAccountId =
            (await dao.getAccountByCode(codeFixedAssets))?.id ??
                invoice.assetId;
        actualCreditAccountId =
            (await dao.getAccountByCode(codeRetainedEarnings))?.id ??
                'retained_earnings';
      } else {
        // Decrease: Debit revaluation deficit (retained earnings), Credit asset
        actualDebitAccountId =
            (await dao.getAccountByCode(codeRetainedEarnings))?.id ??
                'retained_earnings';
        actualCreditAccountId =
            (await dao.getAccountByCode(codeFixedAssets))?.id ??
                invoice.assetId;
      }
    }

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
        accountId: actualDebitAccountId,
        debit: Value(revalAmount),
        credit: Value(Decimal.zero),
        memo: Value('إعادة تقييم: $reason (مدين)'),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: actualCreditAccountId,
        debit: Value(Decimal.zero),
        credit: Value(revalAmount),
        memo: Value('إعادة تقييم: $reason (دائن)'),
        branchId: Value(branchId),
      ),
    ];

    await db.transaction(() async {
      await dao.createEntry(entry, lines);
      await _auditService.logCreate('GLEntry', entryId,
          details: 'Revaluation for invoice ${invoice.id}: $reason');
    });
  }

  Future<void> closeFinancialYear(DateTime date) async {
    final fiscalYear = date.year;

    await db.transaction(() async {
      await (db.update(db.accountingPeriods)
            ..where((p) => p.fiscalYear.equals(fiscalYear)))
          .write(const AccountingPeriodsCompanion(
              isClosed: Value(true), status: Value('CLOSED')));

      await generateOpeningBalances(
          newFiscalYear: fiscalYear + 1, userId: 'SYSTEM');
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
        expenseAmount: amount,
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
        expenseAmount: amount,
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
}
