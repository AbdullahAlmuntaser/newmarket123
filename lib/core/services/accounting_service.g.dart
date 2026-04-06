// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounting_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VatReportData _$VatReportDataFromJson(Map<String, dynamic> json) =>
    VatReportData(
      totalOutputVat: (json['totalOutputVat'] as num).toDouble(),
      totalInputVat: (json['totalInputVat'] as num).toDouble(),
      netVatPayable: (json['netVatPayable'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
    );

Map<String, dynamic> _$VatReportDataToJson(VatReportData instance) =>
    <String, dynamic>{
      'totalOutputVat': instance.totalOutputVat,
      'totalInputVat': instance.totalInputVat,
      'netVatPayable': instance.netVatPayable,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
    };

IncomeStatementData _$IncomeStatementDataFromJson(Map<String, dynamic> json) =>
    IncomeStatementData(
      revenues: (json['revenues'] as List<dynamic>)
          .map((e) => TrialBalanceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>)
          .map((e) => TrialBalanceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      totalExpense: (json['totalExpense'] as num).toDouble(),
      netIncome: (json['netIncome'] as num).toDouble(),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
    );

Map<String, dynamic> _$IncomeStatementDataToJson(
  IncomeStatementData instance,
) => <String, dynamic>{
  'revenues': instance.revenues.map((e) => e.toJson()).toList(),
  'expenses': instance.expenses.map((e) => e.toJson()).toList(),
  'totalRevenue': instance.totalRevenue,
  'totalExpense': instance.totalExpense,
  'netIncome': instance.netIncome,
  'startDate': instance.startDate?.toIso8601String(),
  'endDate': instance.endDate.toIso8601String(),
};

BalanceSheetData _$BalanceSheetDataFromJson(Map<String, dynamic> json) =>
    BalanceSheetData(
      assets: (json['assets'] as List<dynamic>)
          .map((e) => BalanceSheetItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      liabilities: (json['liabilities'] as List<dynamic>)
          .map((e) => BalanceSheetItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      equity: (json['equity'] as List<dynamic>)
          .map((e) => BalanceSheetItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAssets: (json['totalAssets'] as num).toDouble(),
      totalLiabilities: (json['totalLiabilities'] as num).toDouble(),
      totalEquity: (json['totalEquity'] as num).toDouble(),
      netIncome: (json['netIncome'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );

Map<String, dynamic> _$BalanceSheetDataToJson(BalanceSheetData instance) =>
    <String, dynamic>{
      'assets': instance.assets.map((e) => e.toJson()).toList(),
      'liabilities': instance.liabilities.map((e) => e.toJson()).toList(),
      'equity': instance.equity.map((e) => e.toJson()).toList(),
      'totalAssets': instance.totalAssets,
      'totalLiabilities': instance.totalLiabilities,
      'totalEquity': instance.totalEquity,
      'netIncome': instance.netIncome,
      'date': instance.date.toIso8601String(),
    };

BalanceSheetItem _$BalanceSheetItemFromJson(Map<String, dynamic> json) =>
    BalanceSheetItem(
      const GLAccountConverter().fromJson(
        json['account'] as Map<String, dynamic>,
      ),
      (json['balance'] as num).toDouble(),
    );

Map<String, dynamic> _$BalanceSheetItemToJson(BalanceSheetItem instance) =>
    <String, dynamic>{
      'account': const GLAccountConverter().toJson(instance.account),
      'balance': instance.balance,
    };

AccountingDashboardData _$AccountingDashboardDataFromJson(
  Map<String, dynamic> json,
) => AccountingDashboardData(
  totalRevenue: (json['totalRevenue'] as num).toDouble(),
  totalExpenses: (json['totalExpenses'] as num).toDouble(),
  netIncome: (json['netIncome'] as num).toDouble(),
  totalAssets: (json['totalAssets'] as num).toDouble(),
  totalLiabilities: (json['totalLiabilities'] as num).toDouble(),
  topExpenses: (json['topExpenses'] as List<dynamic>)
      .map((e) => TrialBalanceItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  recentTransactions: (json['recentTransactions'] as List<dynamic>)
      .map((e) => const GLEntryConverter().fromJson(e as Map<String, dynamic>))
      .toList(),
  dailyRevenue: (json['dailyRevenue'] as List<dynamic>)
      .map((e) => DailyValue.fromJson(e as Map<String, dynamic>))
      .toList(),
  dailyExpenses: (json['dailyExpenses'] as List<dynamic>)
      .map((e) => DailyValue.fromJson(e as Map<String, dynamic>))
      .toList(),
  topSellingProducts: (json['topSellingProducts'] as List<dynamic>)
      .map((e) => DashboardTopProduct.fromJson(e as Map<String, dynamic>))
      .toList(),
  expiringBatchesCount: (json['expiringBatchesCount'] as num?)?.toInt() ?? 0,
  ratios: FinancialRatiosData.fromJson(json['ratios'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AccountingDashboardDataToJson(
  AccountingDashboardData instance,
) => <String, dynamic>{
  'totalRevenue': instance.totalRevenue,
  'totalExpenses': instance.totalExpenses,
  'netIncome': instance.netIncome,
  'totalAssets': instance.totalAssets,
  'totalLiabilities': instance.totalLiabilities,
  'topExpenses': instance.topExpenses.map((e) => e.toJson()).toList(),
  'recentTransactions': instance.recentTransactions
      .map(const GLEntryConverter().toJson)
      .toList(),
  'dailyRevenue': instance.dailyRevenue.map((e) => e.toJson()).toList(),
  'dailyExpenses': instance.dailyExpenses.map((e) => e.toJson()).toList(),
  'topSellingProducts': instance.topSellingProducts
      .map((e) => e.toJson())
      .toList(),
  'expiringBatchesCount': instance.expiringBatchesCount,
  'ratios': instance.ratios.toJson(),
};

DashboardTopProduct _$DashboardTopProductFromJson(Map<String, dynamic> json) =>
    DashboardTopProduct(
      json['productName'] as String,
      (json['quantity'] as num).toDouble(),
    );

Map<String, dynamic> _$DashboardTopProductToJson(
  DashboardTopProduct instance,
) => <String, dynamic>{
  'productName': instance.productName,
  'quantity': instance.quantity,
};

DailyValue _$DailyValueFromJson(Map<String, dynamic> json) => DailyValue(
  DateTime.parse(json['date'] as String),
  (json['value'] as num).toDouble(),
);

Map<String, dynamic> _$DailyValueToJson(DailyValue instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'value': instance.value,
    };

CashFlowData _$CashFlowDataFromJson(Map<String, dynamic> json) => CashFlowData(
  operatingActivities: (json['operatingActivities'] as num).toDouble(),
  investingActivities: (json['investingActivities'] as num).toDouble(),
  financingActivities: (json['financingActivities'] as num).toDouble(),
  netCashFlow: (json['netCashFlow'] as num).toDouble(),
  beginningCashBalance: (json['beginningCashBalance'] as num).toDouble(),
  endingCashBalance: (json['endingCashBalance'] as num).toDouble(),
  startDate: json['startDate'] == null
      ? null
      : DateTime.parse(json['startDate'] as String),
  endDate: DateTime.parse(json['endDate'] as String),
);

Map<String, dynamic> _$CashFlowDataToJson(CashFlowData instance) =>
    <String, dynamic>{
      'operatingActivities': instance.operatingActivities,
      'investingActivities': instance.investingActivities,
      'financingActivities': instance.financingActivities,
      'netCashFlow': instance.netCashFlow,
      'beginningCashBalance': instance.beginningCashBalance,
      'endingCashBalance': instance.endingCashBalance,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
    };

FinancialRatiosData _$FinancialRatiosDataFromJson(Map<String, dynamic> json) =>
    FinancialRatiosData(
      grossProfitMargin: (json['grossProfitMargin'] as num).toDouble(),
      netProfitMargin: (json['netProfitMargin'] as num).toDouble(),
      currentRatio: (json['currentRatio'] as num).toDouble(),
    );

Map<String, dynamic> _$FinancialRatiosDataToJson(
  FinancialRatiosData instance,
) => <String, dynamic>{
  'grossProfitMargin': instance.grossProfitMargin,
  'netProfitMargin': instance.netProfitMargin,
  'currentRatio': instance.currentRatio,
};
