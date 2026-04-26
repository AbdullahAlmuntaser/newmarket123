import 'package:equatable/equatable.dart';

enum MovementType { addition, deduction, transfer, adjustment }

class StockMovement extends Equatable {
  final String id;
  final String itemId;
  final String unitId;
  final double quantity;
  final double cost;
  final MovementType type;
  final String warehouseId;
  final DateTime timestamp;
  final String? referenceId;

  const StockMovement({
    required this.id,
    required this.itemId,
    required this.unitId,
    required this.quantity,
    required this.cost,
    required this.type,
    required this.warehouseId,
    required this.timestamp,
    this.referenceId,
  });

  @override
  List<Object?> get props => [
    id,
    itemId,
    quantity,
    cost,
    type,
    warehouseId,
    timestamp,
    referenceId,
  ];
}
