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
  final Decimal totalQuantity;
  final Decimal averageCost;
  final Decimal totalValue;

  InventoryValuation({
    required this.productId,
    required this.totalQuantity,
    required this.averageCost,
    required this.totalValue,
  });
}

class BatchWithCost {
  final ProductBatch batch;
  final Decimal remainingQuantity;
  final Decimal costPerUnit;

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

  Future<InventoryValuationMethod> getProductValuationMethod(
      String productId) async {
    final product = await (_db.select(_db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingleOrNull();

    if (product == null) return InventoryValuationMethod.fifo;
    return _parseMethod(product.valuationMethod);
  }

  Future<Decimal> calculateAverageCost(String productId) async {
    final batches = await (_db.select(_db.productBatches)
          ..where((b) => b.productId.equals(productId))
          ..where((b) =>
              b.quantity.isBiggerThan(Constant(Decimal.zero.toString()))))
        .get();

    if (batches.isEmpty) return Decimal.zero;

    Decimal totalValue = Decimal.zero;
    Decimal totalQty = Decimal.zero;

    for (var batch in batches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    return totalQty > Decimal.zero
        ? (totalValue / totalQty).toDecimal()
        : Decimal.zero;
  }

  Future<InventoryValuation> getInventoryValuation(String productId) async {
    final method = await getProductValuationMethod(productId);
    final batches = await (_db.select(_db.productBatches)).get();

    final productBatches = batches
        .where((b) => b.productId == productId && b.quantity > Decimal.zero)
        .toList();

    if (productBatches.isEmpty) {
      return InventoryValuation(
        productId: productId,
        totalQuantity: Decimal.zero,
        averageCost: Decimal.zero,
        totalValue: Decimal.zero,
      );
    }

    switch (method) {
      case InventoryValuationMethod.avco:
        return _calculateAvcoValuation(productId, productBatches);
      case InventoryValuationMethod.lifo:
        return _calculateLifoValuation(productId, productBatches);
      case InventoryValuationMethod.fifo:
      default:
        return _calculateFifoValuation(productId, productBatches);
    }
  }

  Future<InventoryValuation> _calculateAvcoValuation(
      String productId, List<ProductBatch> batches) async {
    Decimal totalValue = Decimal.zero;
    Decimal totalQty = Decimal.zero;

    for (var batch in batches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    final avgCost = totalQty > Decimal.zero
        ? (totalValue / totalQty).toDecimal()
        : Decimal.zero;

    return InventoryValuation(
      productId: productId,
      totalQuantity: totalQty,
      averageCost: avgCost,
      totalValue: totalValue,
    );
  }

  Future<InventoryValuation> _calculateFifoValuation(
      String productId, List<ProductBatch> batches) async {
    final sortedBatches = List<ProductBatch>.from(batches)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    Decimal totalValue = Decimal.zero;
    Decimal totalQty = Decimal.zero;

    for (var batch in sortedBatches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    final avgCost = totalQty > Decimal.zero
        ? (totalValue / totalQty).toDecimal()
        : Decimal.zero;

    return InventoryValuation(
      productId: productId,
      totalQuantity: totalQty,
      averageCost: avgCost,
      totalValue: totalValue,
    );
  }

  Future<InventoryValuation> _calculateLifoValuation(
      String productId, List<ProductBatch> batches) async {
    final sortedBatches = List<ProductBatch>.from(batches)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Decimal totalValue = Decimal.zero;
    Decimal totalQty = Decimal.zero;

    for (var batch in sortedBatches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    final avgCost = totalQty > Decimal.zero
        ? (totalValue / totalQty).toDecimal()
        : Decimal.zero;

    return InventoryValuation(
      productId: productId,
      totalQuantity: totalQty,
      averageCost: avgCost,
      totalValue: totalValue,
    );
  }

  Future<List<BatchWithCost>> getBatchesForSale(
      String productId, Decimal quantity) async {
    final method = await getProductValuationMethod(productId);
    final batches = await (_db.select(_db.productBatches)).get();

    final productBatches = batches
        .where((b) => b.productId == productId && b.quantity > Decimal.zero)
        .toList();

    if (productBatches.isEmpty) return [];

    List<ProductBatch> sortedBatches;

    switch (method) {
      case InventoryValuationMethod.avco:
        return productBatches
            .map((b) => BatchWithCost(
                  batch: b,
                  remainingQuantity: b.quantity,
                  costPerUnit: b.costPrice,
                ))
            .toList();

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

    Decimal remaining = quantity;
    final result = <BatchWithCost>[];

    for (var batch in sortedBatches) {
      if (remaining <= Decimal.zero) break;

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

  Future<Decimal> calculateCogsForSale(
      String productId, Decimal quantity) async {
    final batches = await getBatchesForSale(productId, quantity);

    Decimal totalCogs = Decimal.zero;
    for (var batch in batches) {
      totalCogs += batch.remainingQuantity * batch.costPerUnit;
    }

    return totalCogs;
  }

  Future<void> deductFromInventory({
    required String productId,
    required Decimal quantity,
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
    required Decimal quantity,
    required Decimal cost,
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

  Future<Map<String, Decimal>> getBatchSummaryReport(
      {String? warehouseId}) async {
    final Map<String, Decimal> summary = {};

    final query = _db.select(_db.productBatches);
    if (warehouseId != null) {
      query.where((b) => b.warehouseId.equals(warehouseId));
    }

    final batches = await query.get();

    for (var batch in batches) {
      final key = '${batch.productId}_${batch.warehouseId}';
      summary[key] = (summary[key] ?? Decimal.zero) + batch.quantity;
    }

    return summary;
  }
}
