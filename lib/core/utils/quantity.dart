import 'package:decimal/decimal.dart';

/// Represents a quantity value (for stock/inventory) with its own precision rules.
/// All operations use Decimal internally. No double or num leaks.
class Quantity {
  final Decimal value;
  static const int defaultPrecision = 3;

  const Quantity(this.value);

  factory Quantity.fromDouble(double val) =>
      Quantity(Decimal.parse(val.toString()));
  factory Quantity.fromInt(int val) => Quantity(Decimal.fromInt(val));
  factory Quantity.parse(String val) => Quantity(Decimal.parse(val));
  factory Quantity.fromDecimal(Decimal val) => Quantity(val);

  static final Quantity zero = Quantity(Decimal.zero);

  Quantity operator +(Quantity other) => Quantity(value + other.value);
  Quantity operator -(Quantity other) => Quantity(value - other.value);
  Quantity operator *(dynamic factor) {
    if (factor is Decimal) return Quantity(value * factor);
    if (factor is Quantity) return Quantity(value * factor.value);
    if (factor is int) return Quantity(value * Decimal.fromInt(factor));
    if (factor is String) return Quantity(value * Decimal.parse(factor));
    throw ArgumentError('Unsupported factor type: ${factor.runtimeType}');
  }

  Quantity operator /(dynamic divisor) {
    Decimal div;
    if (divisor is Decimal) {
      div = divisor;
    } else if (divisor is Quantity) {
      div = divisor.value;
    } else if (divisor is int) {
      div = Decimal.fromInt(divisor);
    } else {
      throw ArgumentError('Unsupported divisor type: ${divisor.runtimeType}');
    }
    if (div == Decimal.zero) throw ArgumentError('Division by zero');
    return Quantity((value / div).toDecimal(scaleOnInfinitePrecision: 8));
  }

  bool operator >(Quantity other) => value > other.value;
  bool operator <(Quantity other) => value < other.value;
  bool operator >=(Quantity other) => value >= other.value;
  bool operator <=(Quantity other) => value <= other.value;

  Quantity abs() => Quantity(value.abs());
  Quantity negate() => Quantity(-value);

  bool isZero() => value == Decimal.zero;
  bool isNegative() => value < Decimal.zero;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quantity &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  Decimal toDecimal() => value;
  String toStringAsFixed(int fractionDigits) =>
      value.toStringAsFixed(fractionDigits);

  @override
  String toString() => value.toString();
}
