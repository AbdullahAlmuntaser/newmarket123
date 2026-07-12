import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import '../entities/batch_info.dart';
import '../entities/stock_movement.dart';
import '../../core/utils/failures.dart';

abstract class InventoryRepository {
  Future<Either<Failure, void>> addMovement(StockMovement movement);
  Future<Either<Failure, List<StockMovement>>> getMovementsByItem(
    String itemId,
  );
  Future<Either<Failure, double>> getCurrentStock(String itemId);

  Future<Either<Failure, List<BatchInfo>>> getBatchesByFefo({
    required String productId,
    required String warehouseId,
  });

  Future<Either<Failure, List<BatchAllocation>>> allocateStockFefo({
    required String productId,
    required String warehouseId,
    required Decimal quantityNeeded,
  });

  Future<Either<Failure, List<BatchInfo>>> getExpiringBatches({
    required String warehouseId,
    int daysThreshold = 30,
  });

  Future<Either<Failure, List<BatchInfo>>> getExpiredBatches({
    required String warehouseId,
  });
}

class BatchAllocation {
  final String batchId;
  final Decimal quantity;
  final DateTime? expiryDate;

  const BatchAllocation({
    required this.batchId,
    required this.quantity,
    this.expiryDate,
  });
}
