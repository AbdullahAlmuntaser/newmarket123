import 'package:decimal/decimal.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'balance_sheet_item.dart';

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

  Map<String, dynamic> toJson() => {
        'assets': assets.map((e) => e.toJson()).toList(),
        'liabilities': liabilities.map((e) => e.toJson()).toList(),
        'equity': equity.map((e) => e.toJson()).toList(),
        'totalAssets': totalAssets,
        'totalLiabilities': totalLiabilities,
        'totalEquity': totalEquity,
        'netIncome': netIncome,
        'date': date.toIso8601String(),
      };
}
