import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/domain/entities/batch_info.dart';
import 'package:supermarket/domain/repositories/inventory_repository.dart';

class FefoService {
  final InventoryRepository _repository;

  FefoService({required InventoryRepository repository})
      : _repository = repository;

  Future<Either<Failure, List<BatchInfo>>> getBatchesByFefo({
    required String productId,
    required String warehouseId,
  }) {
    return _repository.getBatchesByFefo(
      productId: productId,
      warehouseId: warehouseId,
    );
  }

  Future<Either<Failure, List<BatchAllocation>>> allocateStockFefo({
    required String productId,
    required String warehouseId,
    required Decimal quantityNeeded,
  }) {
    return _repository.allocateStockFefo(
      productId: productId,
      warehouseId: warehouseId,
      quantityNeeded: quantityNeeded,
    );
  }

  Future<Either<Failure, List<BatchInfo>>> getExpiringProducts({
    required String warehouseId,
    int daysThreshold = 30,
  }) {
    return _repository.getExpiringBatches(
      warehouseId: warehouseId,
      daysThreshold: daysThreshold,
    );
  }

  Future<Either<Failure, List<BatchInfo>>> getExpiredProducts({
    required String warehouseId,
  }) {
    return _repository.getExpiredBatches(warehouseId: warehouseId);
  }
}
