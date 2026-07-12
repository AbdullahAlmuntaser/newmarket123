import 'package:json_annotation/json_annotation.dart';

part 'quotation.g.dart';

@JsonSerializable()
class Quotation {
  final int? id;
  final String quotationNumber;
  final int customerId;
  final int? branchId;
  final int? warehouseId;
  final DateTime date;
  final DateTime? expiryDate;
  final String status;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double totalAmount;
  final String? notes;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Quotation({
    this.id,
    required this.quotationNumber,
    required this.customerId,
    this.branchId,
    this.warehouseId,
    required this.date,
    this.expiryDate,
    this.status = 'draft',
    this.subtotal = 0,
    this.discountTotal = 0,
    this.taxTotal = 0,
    this.totalAmount = 0,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) => _$QuotationFromJson(json);
  Map<String, dynamic> toJson() => _$QuotationToJson(this);
}

@JsonSerializable()
class QuotationItem {
  final int? id;
  final int quotationId;
  final int productId;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final double taxPercent;
  final double taxAmount;
  final double totalAmount;
  final String? notes;

  QuotationItem({
    this.id,
    required this.quotationId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.taxPercent = 0,
    this.taxAmount = 0,
    required this.totalAmount,
    this.notes,
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) => _$QuotationItemFromJson(json);
  Map<String, dynamic> toJson() => _$QuotationItemToJson(this);
}
