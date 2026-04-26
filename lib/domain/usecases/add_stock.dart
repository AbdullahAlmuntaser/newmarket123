import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/core/utils/usecase.dart';
import 'package:supermarket/domain/entities/stock_movement.dart';
import 'package:supermarket/domain/repositories/inventory_repository.dart';

class AddStockUseCase extends UseCase<void, AddStockParams> {
  final InventoryRepository repository;

  AddStockUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(AddStockParams params) async {
    final movement = StockMovement(
      id: '',
      itemId: params.productId,
      unitId: '',
      quantity: params.quantity,
      cost: 0.0,
      type: MovementType.adjustment,
      warehouseId: params.warehouseId,
      timestamp: DateTime.now(),
    );
    return await repository.addMovement(movement);
  }
}

class AddStockParams extends Equatable {
  final String productId;
  final double quantity;
  final String warehouseId;
  final String? batchId;

  const AddStockParams({
    required this.productId,
    required this.quantity,
    required this.warehouseId,
    this.batchId,
  });

  @override
  List<Object?> get props => [productId, quantity, warehouseId, batchId];
}
