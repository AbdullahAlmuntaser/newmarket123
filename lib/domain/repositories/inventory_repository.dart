import 'package:dartz/dartz.dart';
import '../entities/stock_movement.dart';
import '../../core/utils/failures.dart';

abstract class InventoryRepository {
  Future<Either<Failure, void>> addMovement(StockMovement movement);
  Future<Either<Failure, List<StockMovement>>> getMovementsByItem(
    String itemId,
  );
  Future<Either<Failure, double>> getCurrentStock(String itemId);
}
