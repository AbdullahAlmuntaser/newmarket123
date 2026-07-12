import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class BatchInfo extends Equatable {
  final String id;
  final String productId;
  final String warehouseId;
  final String batchNumber;
  final DateTime? expiryDate;
  final Decimal quantity;
  final Decimal initialQuantity;
  final Decimal costPrice;

  const BatchInfo({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.batchNumber,
    this.expiryDate,
    required this.quantity,
    required this.initialQuantity,
    required this.costPrice,
  });

  BatchInfo copyWith({Decimal? quantity}) {
    return BatchInfo(
      id: id,
      productId: productId,
      warehouseId: warehouseId,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity,
      costPrice: costPrice,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        warehouseId,
        batchNumber,
        expiryDate,
        quantity,
        initialQuantity,
        costPrice,
      ];
}
