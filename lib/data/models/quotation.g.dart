// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quotation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quotation _$QuotationFromJson(Map<String, dynamic> json) => Quotation(
      id: (json['id'] as num?)?.toInt(),
      quotationNumber: json['quotationNumber'] as String,
      customerId: (json['customerId'] as num).toInt(),
      branchId: (json['branchId'] as num?)?.toInt(),
      warehouseId: (json['warehouseId'] as num?)?.toInt(),
      date: DateTime.parse(json['date'] as String),
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      status: json['status'] as String? ?? 'draft',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discountTotal: (json['discountTotal'] as num?)?.toDouble() ?? 0,
      taxTotal: (json['taxTotal'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdBy: (json['createdBy'] as num?)?.toInt(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$QuotationToJson(Quotation instance) => <String, dynamic>{
      'id': instance.id,
      'quotationNumber': instance.quotationNumber,
      'customerId': instance.customerId,
      'branchId': instance.branchId,
      'warehouseId': instance.warehouseId,
      'date': instance.date.toIso8601String(),
      'expiryDate': instance.expiryDate?.toIso8601String(),
      'status': instance.status,
      'subtotal': instance.subtotal,
      'discountTotal': instance.discountTotal,
      'taxTotal': instance.taxTotal,
      'totalAmount': instance.totalAmount,
      'notes': instance.notes,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

QuotationItem _$QuotationItemFromJson(Map<String, dynamic> json) =>
    QuotationItem(
      id: (json['id'] as num?)?.toInt(),
      quotationId: (json['quotationId'] as num).toInt(),
      productId: (json['productId'] as num).toInt(),
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$QuotationItemToJson(QuotationItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'quotationId': instance.quotationId,
      'productId': instance.productId,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'discountPercent': instance.discountPercent,
      'discountAmount': instance.discountAmount,
      'taxPercent': instance.taxPercent,
      'taxAmount': instance.taxAmount,
      'totalAmount': instance.totalAmount,
      'notes': instance.notes,
    };
