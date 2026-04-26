import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/stock_movement_dao.dart';

enum InventoryTransactionType {
  purchase,
  sale,
  purchaseReturn,
  saleReturn,
  adjustment,
}

class InventoryValuation {
  final String productId;
  final double totalQuantity;
  final double averageCost;

  InventoryValuation({
    required this.productId,
    required this.totalQuantity,
    required this.averageCost,
  });
}

class InventoryCostingService {
  final StockMovementDao _stockMovementDao;

  InventoryCostingService(this._stockMovementDao);

  Future<List<InventoryValuation>> getInventoryValuation() async {
    final movements = await _stockMovementDao.getAllStockMovements();
    final valuationMap = <String, InventoryValuation>{};

    for (var movement in movements) {
      final existing = valuationMap[movement.productId];
      double currentStock = existing?.totalQuantity ?? 0;
      double currentCost = existing?.averageCost ?? 0;

      if (movement.quantity > 0) {
        final newCost = _calculateWeightedAverageCost(
          currentStock: currentStock,
          currentCost: currentCost,
          addedQuantity: movement.quantity,
          addedCost: 0.0,
        );
        valuationMap[movement.productId] = InventoryValuation(
          productId: movement.productId,
          totalQuantity: currentStock + movement.quantity,
          averageCost: newCost,
        );
      } else {
        valuationMap[movement.productId] = InventoryValuation(
          productId: movement.productId,
          totalQuantity: currentStock + movement.quantity,
          averageCost: currentCost,
        );
      }
    }
    return valuationMap.values.toList();
  }

  Future<void> deductFromInventory(
    String productId,
    double quantity,
    InventoryTransactionType type, {
    String? transactionId,
  }) async {
    await _stockMovementDao.insertStockMovement(
      StockMovementsCompanion.insert(
        productId: productId,
        quantity: -quantity,
        type: type.name,
      ),
    );
  }

  Future<void> returnToInventory(
    String productId,
    double quantity,
    double cost,
    InventoryTransactionType type, {
    String? transactionId,
  }) async {
    await _stockMovementDao.insertStockMovement(
      StockMovementsCompanion.insert(
        productId: productId,
        quantity: quantity,
        type: type.name,
      ),
    );
  }

  double _calculateWeightedAverageCost({
    required double currentStock,
    required double currentCost,
    required double addedQuantity,
    required double addedCost,
  }) {
    if (currentStock + addedQuantity <= 0) return addedCost;

    double totalCost =
        (currentStock * currentCost) + (addedQuantity * addedCost);
    return totalCost / (currentStock + addedQuantity);
  }
}
