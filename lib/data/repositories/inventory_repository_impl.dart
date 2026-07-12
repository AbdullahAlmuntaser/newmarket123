import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/domain/entities/batch_info.dart';
import 'package:supermarket/domain/entities/stock_movement.dart' as entity;
import 'package:supermarket/domain/repositories/inventory_repository.dart';
import 'package:supermarket/data/datasources/local/daos/stock_movement_dao.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

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
          quantity: Decimal.parse(movement.quantity.toString()),
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
                quantity: m.quantity.toDouble(),
                cost: Decimal.zero,
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
      return Right(product?.stock.toDouble() ?? 0.0);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BatchInfo>>> getBatchesByFefo({
    required String productId,
    required String warehouseId,
  }) async {
    try {
      final batches = await _productsDao.getBatchesByFefo(
        productId,
        warehouseId,
      );
      return Right(batches.map(_toBatchInfo).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BatchAllocation>>> allocateStockFefo({
    required String productId,
    required String warehouseId,
    required Decimal quantityNeeded,
  }) async {
    try {
      final batches = await _productsDao.getBatchesByFefo(
        productId,
        warehouseId,
      );
      var remaining = quantityNeeded;
      final allocations = <BatchAllocation>[];

      for (final batch in batches) {
        if (remaining <= Decimal.zero) break;
        final allocate =
            remaining > batch.quantity ? batch.quantity : remaining;
        allocations.add(BatchAllocation(
          batchId: batch.id,
          quantity: allocate,
          expiryDate: batch.expiryDate,
        ));
        remaining -= allocate;
      }

      if (remaining > Decimal.zero) {
        return Left(DatabaseFailure(
          'Insufficient stock. Still need: $remaining',
        ));
      }

      return Right(allocations);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BatchInfo>>> getExpiringBatches({
    required String warehouseId,
    int daysThreshold = 30,
  }) async {
    try {
      final batches = await _productsDao.getExpiringBatches(
        daysThreshold: daysThreshold,
      );
      final filtered =
          batches.where((b) => b.warehouseId == warehouseId).toList();
      return Right(filtered.map(_toBatchInfo).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BatchInfo>>> getExpiredBatches({
    required String warehouseId,
  }) async {
    try {
      final batches = await _productsDao.getExpiredBatches(
        warehouseId: warehouseId,
      );
      return Right(batches.map(_toBatchInfo).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  BatchInfo _toBatchInfo(ProductBatch batch) {
    return BatchInfo(
      id: batch.id,
      productId: batch.productId,
      warehouseId: batch.warehouseId,
      batchNumber: batch.batchNumber,
      expiryDate: batch.expiryDate,
      quantity: batch.quantity,
      initialQuantity: batch.initialQuantity,
      costPrice: batch.costPrice,
    );
  }
}
