import 'package:drift/drift.dart';
import 'package:decimal/decimal.dart';

class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();
  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);
  @override
  String toSql(Decimal value) => value.toString();
}
