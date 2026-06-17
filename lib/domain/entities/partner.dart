import 'package:decimal/decimal.dart';

class Partner {
  final String id;
  final String name;
  final bool isCustomer;
  final Decimal creditLimit;
  final int paymentTermsDays;
  final Decimal openingBalance;

  const Partner({
    required this.id,
    required this.name,
    required this.isCustomer,
    required this.creditLimit,
    required this.paymentTermsDays,
    required this.openingBalance,
  });
}
