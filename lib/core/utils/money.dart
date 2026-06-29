import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Represents a monetary value with fixed precision.
/// All operations use Decimal internally. No double or num leaks.
class Money {
  final Decimal value;
  static const int defaultPrecision = 2;

  const Money(this.value);

  factory Money.fromDouble(double val) => Money(Decimal.parse(val.toString()));
  factory Money.fromInt(int val) => Money(Decimal.fromInt(val));
  factory Money.parse(String val) => Money(Decimal.parse(val));
  factory Money.fromDecimal(Decimal val) => Money(val);

  static final Money zero = Money(Decimal.zero);

  Money operator +(Money other) => Money(value + other.value);
  Money operator -(Money other) => Money(value - other.value);
  Money operator *(dynamic factor) {
    if (factor is Decimal) return Money(value * factor);
    if (factor is Money) return Money(value * factor.value);
    if (factor is int) return Money(value * Decimal.fromInt(factor));
    if (factor is String) return Money(value * Decimal.parse(factor));
    throw ArgumentError('Unsupported factor type: ${factor.runtimeType}');
  }

  Money operator /(dynamic divisor) {
    Decimal div;
    if (divisor is Decimal) {
      div = divisor;
    } else if (divisor is Money) {
      div = divisor.value;
    } else if (divisor is int) {
      div = Decimal.fromInt(divisor);
    } else {
      throw ArgumentError('Unsupported divisor type: ${divisor.runtimeType}');
    }
    if (div == Decimal.zero) throw ArgumentError('Division by zero');
    return Money((value / div).toDecimal(scaleOnInfinitePrecision: 8));
  }

  bool operator >(Money other) => value > other.value;
  bool operator <(Money other) => value < other.value;
  bool operator >=(Money other) => value >= other.value;
  bool operator <=(Money other) => value <= other.value;

  Money abs() => Money(value.abs());
  Money negate() => Money(-value);

  bool isZero() => value == Decimal.zero;
  bool isNegative() => value < Decimal.zero;
  bool isPositive() => value > Decimal.zero;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  Decimal toDecimal() => value;
  String toStringAsFixed(int fractionDigits) =>
      value.toStringAsFixed(fractionDigits);

  String format({String locale = 'en_US', String symbol = ''}) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: defaultPrecision,
    );
    return formatter.format(value.toDouble());
  }

  @override
  String toString() => value.toString();
}
