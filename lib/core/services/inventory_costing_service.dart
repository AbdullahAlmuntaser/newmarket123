import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/stock_movement_dao.dart';

enum InventoryValuationMethod {
  fifo,
  avco,
  lifo,
}

enum InventoryTransactionType {
  purchase,
  sale,
  purchaseReturn,
  saleReturn,
  adjustment,
  transferIn,
  transferOut,
}

class InventoryValuation {
  final String productId;
  final double totalQuantity;
  final double averageCost;
  final double totalValue;

  InventoryValuation({
    required this.productId,
    required this.totalQuantity,
    required this.averageCost,
    required this.totalValue,
  });
}

class BatchWithCost {
  final ProductBatch batch;
  final double remainingQuantity;
  final double costPerUnit;

  BatchWithCost({
    required this.batch,
    required this.remainingQuantity,
    required this.costPerUnit,
  });
}

class InventoryCostingService {
  final StockMovementDao _stockMovementDao;
  final AppDatabase _db;

  InventoryCostingService(this._stockMovementDao, this._db);

  InventoryValuationMethod _parseMethod(String? method) {
    switch (method?.toUpperCase()) {
      case 'AVCO':
        return InventoryValuationMethod.avco;
      case 'LIFO':
        return InventoryValuationMethod.lifo;
      default:
        return InventoryValuationMethod.fifo;
    }
  }

  Future<InventoryValuationMethod> getProductValuationMethod(String productId) async {
    final product = await (_db.select(_db.products)
      ..where((p) => p.id.equals(productId)))
      .getSingleOrNull();
    
    if (product == null) return InventoryValuationMethod.fifo;
    return _parseMethod(product.valuationMethod);
  }

  Future<double> calculateAverageCost(String productId) async {
    final batches = await (_db.select(_db.productBatches)
      ..where((b) => b.productId.equals(productId))
      ..where((b) => b.quantity.isBiggerThan(const Variable(0.0))))
      .get();

    if (batches.isEmpty) return 0.0;

    double totalValue = 0.0;
    double totalQty = 0.0;

    for (var batch in batches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    return totalQty > 0 ? totalValue / totalQty : 0.0;
  }

  Future<InventoryValuation> getInventoryValuation(String productId) async {
    final method = await getProductValuationMethod(productId);
    final batches = await (_db.select(_db.productBatches))
      .get();

    final productBatches = batches.where((b) => b.productId == productId && b.quantity > 0).toList();
    
    if (productBatches.isEmpty) {
      return InventoryValuation(
        productId: productId,
        totalQuantity: 0,
        averageCost: 0,
        totalValue: 0,
      );
    }

    switch (method) {
      case InventoryValuationMethod.avco:
        return await _calculateAvcoValuation(productId, productBatches);
      case InventoryValuationMethod.lifo:
        return await _calculateLifoValuation(productId, productBatches);
      case InventoryValuationMethod.fifo:
      default:
        return await _calculateFifoValuation(productId, productBatches);
    }
  }

  Future<InventoryValuation> _calculateAvcoValuation(String productId, List<ProductBatch> batches) async {
    double totalValue = 0.0;
    double totalQty = 0.0;

    for (var batch in batches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    final avgCost = totalQty > 0 ? totalValue / totalQty : 0.0;

    return InventoryValuation(
      productId: productId,
      totalQuantity: totalQty,
      averageCost: avgCost,
      totalValue: totalValue,
    );
  }

  Future<InventoryValuation> _calculateFifoValuation(String productId, List<ProductBatch> batches) async {
    final sortedBatches = List<ProductBatch>.from(batches)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    double totalValue = 0.0;
    double totalQty = 0.0;

    for (var batch in sortedBatches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    final avgCost = totalQty > 0 ? totalValue / totalQty : 0.0;

    return InventoryValuation(
      productId: productId,
      totalQuantity: totalQty,
      averageCost: avgCost,
      totalValue: totalValue,
    );
  }

  Future<InventoryValuation> _calculateLifoValuation(String productId, List<ProductBatch> batches) async {
    final sortedBatches = List<ProductBatch>.from(batches)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double totalValue = 0.0;
    double totalQty = 0.0;

    for (var batch in sortedBatches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    final avgCost = totalQty > 0 ? totalValue / totalQty : 0.0;

    return InventoryValuation(
      productId: productId,
      totalQuantity: totalQty,
      averageCost: avgCost,
      totalValue: totalValue,
    );
  }

  Future<List<BatchWithCost>> getBatchesForSale(String productId, double quantity) async {
    final method = await getProductValuationMethod(productId);
    final batches = await (_db.select(_db.productBatches))
      .get();

    final productBatches = batches.where((b) => b.productId == productId && b.quantity > 0).toList();
    
    if (productBatches.isEmpty) return [];

    List<ProductBatch> sortedBatches;
    
    switch (method) {
      case InventoryValuationMethod.avco:
        return productBatches.map((b) => BatchWithCost(
          batch: b,
          remainingQuantity: b.quantity,
          costPerUnit: b.costPrice,
        )).toList();
        
      case InventoryValuationMethod.lifo:
        sortedBatches = List<ProductBatch>.from(productBatches)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
        
      case InventoryValuationMethod.fifo:
      default:
        sortedBatches = List<ProductBatch>.from(productBatches)
          ..sort((a, b) {
            if (a.expiryDate == null && b.expiryDate == null) {
              return a.createdAt.compareTo(b.createdAt);
            }
            if (a.expiryDate == null) return 1;
            if (b.expiryDate == null) return -1;
            return a.expiryDate!.compareTo(b.expiryDate!);
          });
    }

    double remaining = quantity;
    final result = <BatchWithCost>[];
    
    for (var batch in sortedBatches) {
      if (remaining <= 0) break;
      
      final deduct = remaining > batch.quantity ? batch.quantity : remaining;
      result.add(BatchWithCost(
        batch: batch,
        remainingQuantity: deduct,
        costPerUnit: batch.costPrice,
      ));
      remaining -= deduct;
    }

    return result;
  }

  Future<double> calculateCogsForSale(String productId, double quantity) async {
    final batches = await getBatchesForSale(productId, quantity);
    
    double totalCogs = 0.0;
    for (var batch in batches) {
      totalCogs += batch.remainingQuantity * batch.costPerUnit;
    }
    
    return totalCogs;
  }

  Future<void> deductFromInventory({
    required String productId,
    required double quantity,
    required InventoryTransactionType type,
    String? transactionId,
  }) async {
    await _stockMovementDao.insertStockMovement(
      StockMovementsCompanion.insert(
        productId: productId,
        quantity: -quantity,
        type: type.name,
        referenceId: Value(transactionId),
      ),
    );
  }

  Future<void> addToInventory({
    required String productId,
    required double quantity,
    required double cost,
    required InventoryTransactionType type,
    String? transactionId,
  }) async {
    await _stockMovementDao.insertStockMovement(
      StockMovementsCompanion.insert(
        productId: productId,
        quantity: quantity,
        cost: Value(cost),
        type: type.name,
        referenceId: Value(transactionId),
      ),
    );
  }

  Future<Map<String, double>> getBatchSummaryReport({String? warehouseId}) async {
    final Map<String, double> summary = {};
    
    final query = _db.select(_db.productBatches);
    if (warehouseId != null) {
      query.where((b) => b.warehouseId.equals(warehouseId));
    }
    
    final batches = await query.get();
    
    for (var batch in batches) {
      final key = '${batch.productId}_${batch.warehouseId}';
      summary[key] = (summary[key] ?? 0) + batch.quantity;
    }
    
    return summary;
  }
}