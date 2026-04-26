import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/domain/entities/stock_movement.dart' as entity;
import 'package:supermarket/domain/repositories/inventory_repository.dart';
import 'package:supermarket/data/datasources/local/daos/stock_movement_dao.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final StockMovementDao _stockMovementDao;
  final ProductsDao _productsDao;

  InventoryRepositoryImpl(this._stockMovementDao, this._productsDao);

  @override
  Future<Either<Failure, void>> addMovement(
    entity.StockMovement movement,
  ) async {
    try {
      await _stockMovementDao.insertStockMovement(
        StockMovementsCompanion.insert(
          productId: movement.itemId,
          quantity: movement.quantity,
          type: movement.type.name,
          referenceId: Value(movement.referenceId),
        ),
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<entity.StockMovement>>> getMovementsByItem(
    String itemId,
  ) async {
    try {
      final movements = await _stockMovementDao.getAllStockMovements();
      final filtered = movements.where((m) => m.productId == itemId).toList();
      return Right(
        filtered
            .map(
              (m) => entity.StockMovement(
                id: m.id,
                itemId: m.productId,
                unitId: '',
                quantity: m.quantity,
                cost: 0.0,
                type: entity.MovementType.values.firstWhere(
                  (t) => t.name == m.type,
                  orElse: () => entity.MovementType.adjustment,
                ),
                warehouseId: m.fromWarehouseId ?? '',
                timestamp: m.movementDate,
                referenceId: m.referenceId,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getCurrentStock(String itemId) async {
    try {
      final product = await _productsDao.getProductById(itemId);
      return Right(product?.stock ?? 0.0);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
