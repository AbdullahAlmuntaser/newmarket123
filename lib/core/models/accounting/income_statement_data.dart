import 'package:decimal/decimal.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';

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

  Map<String, dynamic> toJson() => {
        'revenues': revenues.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'totalRevenue': totalRevenue,
        'totalExpense': totalExpense,
        'netIncome': netIncome,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
}
