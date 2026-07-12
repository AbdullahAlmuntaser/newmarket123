import 'package:supermarket/data/datasources/local/app_database.dart';

class SalesLineItem {
  Product? product;
  double quantity;
  double price;
  String selectedUnit;
  double discount;
  double unitFactor;
  String? costCenterId;

  SalesLineItem({
    this.product,
    this.quantity = 1,
    this.price = 0,
    this.selectedUnit = '',
    this.discount = 0,
    this.unitFactor = 1,
    this.costCenterId,
  });

  double get lineTotal => quantity * price;
}
