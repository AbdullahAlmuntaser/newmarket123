// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounting_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountingDashboardData _$AccountingDashboardDataFromJson(
        Map<String, dynamic> json) =>
    AccountingDashboardData(
      totalRevenue: Decimal.fromJson(json['totalRevenue'] as String),
      totalExpenses: Decimal.fromJson(json['totalExpenses'] as String),
      netIncome: Decimal.fromJson(json['netIncome'] as String),
      totalAssets: Decimal.fromJson(json['totalAssets'] as String),
      totalLiabilities: Decimal.fromJson(json['totalLiabilities'] as String),
      topExpenses: (json['topExpenses'] as List<dynamic>)
          .map((e) => TrialBalanceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentTransactions: (json['recentTransactions'] as List<dynamic>)
          .map((e) =>
              const GLEntryConverter().fromJson(e as Map<String, dynamic>))
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
      expiringBatchesCount:
          (json['expiringBatchesCount'] as num?)?.toInt() ?? 0,
      ratios:
          FinancialRatiosData.fromJson(json['ratios'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AccountingDashboardDataToJson(
        AccountingDashboardData instance) =>
    <String, dynamic>{
      'totalRevenue': instance.totalRevenue.toJson(),
      'totalExpenses': instance.totalExpenses.toJson(),
      'netIncome': instance.netIncome.toJson(),
      'totalAssets': instance.totalAssets.toJson(),
      'totalLiabilities': instance.totalLiabilities.toJson(),
      'topExpenses': instance.topExpenses.map((e) => e.toJson()).toList(),
      'recentTransactions': instance.recentTransactions
          .map(const GLEntryConverter().toJson)
          .toList(),
      'dailyRevenue': instance.dailyRevenue.map((e) => e.toJson()).toList(),
      'dailyExpenses': instance.dailyExpenses.map((e) => e.toJson()).toList(),
      'topSellingProducts':
          instance.topSellingProducts.map((e) => e.toJson()).toList(),
      'expiringBatchesCount': instance.expiringBatchesCount,
      'ratios': instance.ratios.toJson(),
    };

DashboardTopProduct _$DashboardTopProductFromJson(Map<String, dynamic> json) =>
    DashboardTopProduct(
      json['productName'] as String,
      Decimal.fromJson(json['quantity'] as String),
    );

Map<String, dynamic> _$DashboardTopProductToJson(
        DashboardTopProduct instance) =>
    <String, dynamic>{
      'productName': instance.productName,
      'quantity': instance.quantity,
    };

DailyValue _$DailyValueFromJson(Map<String, dynamic> json) => DailyValue(
      DateTime.parse(json['date'] as String),
      Decimal.fromJson(json['value'] as String),
    );

Map<String, dynamic> _$DailyValueToJson(DailyValue instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'value': instance.value,
    };

CashFlowData _$CashFlowDataFromJson(Map<String, dynamic> json) => CashFlowData(
      operatingActivities:
          Decimal.fromJson(json['operatingActivities'] as String),
      investingActivities:
          Decimal.fromJson(json['investingActivities'] as String),
      financingActivities:
          Decimal.fromJson(json['financingActivities'] as String),
      netCashFlow: Decimal.fromJson(json['netCashFlow'] as String),
      beginningCashBalance:
          Decimal.fromJson(json['beginningCashBalance'] as String),
      endingCashBalance: Decimal.fromJson(json['endingCashBalance'] as String),
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
      grossProfitMargin: Decimal.fromJson(json['grossProfitMargin'] as String),
      netProfitMargin: Decimal.fromJson(json['netProfitMargin'] as String),
      currentRatio: Decimal.fromJson(json['currentRatio'] as String),
    );

Map<String, dynamic> _$FinancialRatiosDataToJson(
        FinancialRatiosData instance) =>
    <String, dynamic>{
      'grossProfitMargin': instance.grossProfitMargin,
      'netProfitMargin': instance.netProfitMargin,
      'currentRatio': instance.currentRatio,
    };

VatReportData _$VatReportDataFromJson(Map<String, dynamic> json) =>
    VatReportData(
      totalTaxableSales: Decimal.fromJson(json['totalTaxableSales'] as String),
      totalOutputVat: Decimal.fromJson(json['totalOutputVat'] as String),
      totalTaxablePurchases:
          Decimal.fromJson(json['totalTaxablePurchases'] as String),
      totalInputVat: Decimal.fromJson(json['totalInputVat'] as String),
      netVatPayable: Decimal.fromJson(json['netVatPayable'] as String),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
    );

Map<String, dynamic> _$VatReportDataToJson(VatReportData instance) =>
    <String, dynamic>{
      'totalTaxableSales': instance.totalTaxableSales,
      'totalOutputVat': instance.totalOutputVat,
      'totalTaxablePurchases': instance.totalTaxablePurchases,
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
      totalRevenue: Decimal.fromJson(json['totalRevenue'] as String),
      totalExpense: Decimal.fromJson(json['totalExpense'] as String),
      netIncome: Decimal.fromJson(json['netIncome'] as String),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
    );

Map<String, dynamic> _$IncomeStatementDataToJson(
        IncomeStatementData instance) =>
    <String, dynamic>{
      'revenues': instance.revenues.map((e) => e.toJson()).toList(),
      'expenses': instance.expenses.map((e) => e.toJson()).toList(),
      'totalRevenue': instance.totalRevenue.toJson(),
      'totalExpense': instance.totalExpense.toJson(),
      'netIncome': instance.netIncome.toJson(),
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
      totalAssets: Decimal.fromJson(json['totalAssets'] as String),
      totalLiabilities: Decimal.fromJson(json['totalLiabilities'] as String),
      totalEquity: Decimal.fromJson(json['totalEquity'] as String),
      netIncome: Decimal.fromJson(json['netIncome'] as String),
      date: DateTime.parse(json['date'] as String),
    );

Map<String, dynamic> _$BalanceSheetDataToJson(BalanceSheetData instance) =>
    <String, dynamic>{
      'assets': instance.assets.map((e) => e.toJson()).toList(),
      'liabilities': instance.liabilities.map((e) => e.toJson()).toList(),
      'equity': instance.equity.map((e) => e.toJson()).toList(),
      'totalAssets': instance.totalAssets.toJson(),
      'totalLiabilities': instance.totalLiabilities.toJson(),
      'totalEquity': instance.totalEquity.toJson(),
      'netIncome': instance.netIncome.toJson(),
      'date': instance.date.toIso8601String(),
    };

BalanceSheetItem _$BalanceSheetItemFromJson(Map<String, dynamic> json) =>
    BalanceSheetItem(
      const GLAccountConverter()
          .fromJson(json['account'] as Map<String, dynamic>),
      Decimal.fromJson(json['balance'] as String),
    );

Map<String, dynamic> _$BalanceSheetItemToJson(BalanceSheetItem instance) =>
    <String, dynamic>{
      'account': const GLAccountConverter().toJson(instance.account),
      'balance': instance.balance.toJson(),
    };
