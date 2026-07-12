import 'package:decimal/decimal.dart';

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

  factory CashFlowData.fromJson(Map<String, dynamic> json) => CashFlowData(
        operatingActivities:
            Decimal.fromJson(json['operatingActivities'] as String),
        investingActivities:
            Decimal.fromJson(json['investingActivities'] as String),
        financingActivities:
            Decimal.fromJson(json['financingActivities'] as String),
        netCashFlow: Decimal.fromJson(json['netCashFlow'] as String),
        beginningCashBalance:
            Decimal.fromJson(json['beginningCashBalance'] as String),
        endingCashBalance:
            Decimal.fromJson(json['endingCashBalance'] as String),
        startDate: json['startDate'] == null
            ? null
            : DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
      );

  Map<String, dynamic> toJson() => {
        'operatingActivities': operatingActivities,
        'investingActivities': investingActivities,
        'financingActivities': financingActivities,
        'netCashFlow': netCashFlow,
        'beginningCashBalance': beginningCashBalance,
        'endingCashBalance': endingCashBalance,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
}
