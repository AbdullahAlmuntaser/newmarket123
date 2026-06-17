import 'package:decimal/decimal.dart';

class ProfitReport {
  final Decimal sales;
  final Decimal cost;
  final Decimal netProfit;

  const ProfitReport({
    required this.sales,
    required this.cost,
    required this.netProfit,
  });
}
