import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'daily_value.dart';
import 'dashboard_top_product.dart';
import 'financial_ratios_data.dart';

class AccountingDashboardData {
  final Decimal totalRevenue;
  final Decimal totalExpenses;
  final Decimal netIncome;
  final Decimal totalAssets;
  final Decimal totalLiabilities;
  final List<TrialBalanceItem> topExpenses;
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
            .map((e) => GLEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyRevenue: (json['dailyRevenue'] as List<dynamic>)
            .map((e) => DailyValue.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyExpenses: (json['dailyExpenses'] as List<dynamic>)
            .map((e) => DailyValue.fromJson(e as Map<String, dynamic>))
            .toList(),
        topSellingProducts: (json['topSellingProducts'] as List<dynamic>)
            .map(
                (e) => DashboardTopProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        expiringBatchesCount:
            (json['expiringBatchesCount'] as num?)?.toInt() ?? 0,
        ratios: FinancialRatiosData.fromJson(
            json['ratios'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'totalRevenue': totalRevenue,
        'totalExpenses': totalExpenses,
        'netIncome': netIncome,
        'totalAssets': totalAssets,
        'totalLiabilities': totalLiabilities,
        'topExpenses': topExpenses.map((e) => e.toJson()).toList(),
        'recentTransactions':
            recentTransactions.map((e) => e.toJson()).toList(),
        'dailyRevenue': dailyRevenue.map((e) => e.toJson()).toList(),
        'dailyExpenses': dailyExpenses.map((e) => e.toJson()).toList(),
        'topSellingProducts':
            topSellingProducts.map((e) => e.toJson()).toList(),
        'expiringBatchesCount': expiringBatchesCount,
        'ratios': ratios.toJson(),
      };
}
