import 'package:decimal/decimal.dart';

class DashboardTopProduct {
  final String productName;
  final Decimal quantity;

  DashboardTopProduct(this.productName, this.quantity);

  factory DashboardTopProduct.fromJson(Map<String, dynamic> json) =>
      DashboardTopProduct(
        json['productName'] as String,
        Decimal.fromJson(json['quantity'] as String),
      );

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'quantity': quantity,
      };
}
