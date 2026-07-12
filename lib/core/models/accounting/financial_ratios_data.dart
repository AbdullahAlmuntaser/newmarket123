import 'package:decimal/decimal.dart';

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
      FinancialRatiosData(
        grossProfitMargin: Decimal.fromJson(json['grossProfitMargin'] as String),
        netProfitMargin: Decimal.fromJson(json['netProfitMargin'] as String),
        currentRatio: Decimal.fromJson(json['currentRatio'] as String),
      );

  Map<String, dynamic> toJson() => {
        'grossProfitMargin': grossProfitMargin,
        'netProfitMargin': netProfitMargin,
        'currentRatio': currentRatio,
      };
}
