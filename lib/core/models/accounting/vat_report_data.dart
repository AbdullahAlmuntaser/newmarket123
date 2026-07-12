import 'package:decimal/decimal.dart';

class VatReportData {
  final Decimal totalTaxableSales;
  final Decimal totalOutputVat;
  final Decimal totalTaxablePurchases;
  final Decimal totalInputVat;
  final Decimal netVatPayable;
  final DateTime startDate;
  final DateTime endDate;

  VatReportData({
    required this.totalTaxableSales,
    required this.totalOutputVat,
    required this.totalTaxablePurchases,
    required this.totalInputVat,
    required this.netVatPayable,
    required this.startDate,
    required this.endDate,
  });

  factory VatReportData.fromJson(Map<String, dynamic> json) => VatReportData(
        totalTaxableSales:
            Decimal.fromJson(json['totalTaxableSales'] as String),
        totalOutputVat: Decimal.fromJson(json['totalOutputVat'] as String),
        totalTaxablePurchases:
            Decimal.fromJson(json['totalTaxablePurchases'] as String),
        totalInputVat: Decimal.fromJson(json['totalInputVat'] as String),
        netVatPayable: Decimal.fromJson(json['netVatPayable'] as String),
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
      );

  Map<String, dynamic> toJson() => {
        'totalTaxableSales': totalTaxableSales,
        'totalOutputVat': totalOutputVat,
        'totalTaxablePurchases': totalTaxablePurchases,
        'totalInputVat': totalInputVat,
        'netVatPayable': netVatPayable,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
}
