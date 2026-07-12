import 'package:decimal/decimal.dart';

class DailyValue {
  final DateTime date;
  final Decimal value;

  DailyValue(this.date, this.value);

  factory DailyValue.fromJson(Map<String, dynamic> json) => DailyValue(
        DateTime.parse(json['date'] as String),
        Decimal.fromJson(json['value'] as String),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'value': value,
      };
}
