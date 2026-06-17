import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

class BreakResult {
  final String sourceBatchId;
  final String? targetBatchId;
  final Decimal brokenQuantity;
  final Decimal costPerUnit;

  BreakResult({
    required this.sourceBatchId,
    this.targetBatchId,
    required this.brokenQuantity,
    required this.costPerUnit,
  });
}

class PackagingEngine {
  final AppDatabase db;
  final InventoryCostingService? costingService;

  PackagingEngine(this.db, {this.costingService});

  Future<List<ProductUnit>> getPackagingHierarchy(String productId) async {
    return (db.select(db.productUnits)
          ..where((u) => u.productId.equals(productId))
          ..orderBy(
              [(u) => OrderingTerm(expression: u.unitFactor, mode: OrderingMode.asc)]))
        .get();
  }

  Future<List<BreakResult>> autoBreakIfNecessary({
    required String productId,
    required String warehouseId,
    required Decimal requiredQtyInBase,
  }) async {
    final results = <BreakResult>[];
    if (requiredQtyInBase <= Decimal.zero) return results;

    final hierarchy = await getPackagingHierarchy(productId);
    if (hierarchy.isEmpty) return results;

    final availableBaseQty = await _getAvailableQuantity(productId, warehouseId);
    if (availableBaseQty >= requiredQtyInBase) return results;

    Decimal shortfall = requiredQtyInBase - availableBaseQty;
    final sortedDesc = hierarchy
        .where((u) => u.unitFactor > Decimal.one)
        .toList()
      ..sort((a, b) => b.unitFactor.compareTo(a.unitFactor));

    int maxBreaks = 100;
    int breakCount = 0;

    for (final unit in sortedDesc) {
      if (shortfall <= Decimal.zero) break;

      final batches = await _getBatchesHavingAtLeast(productId, warehouseId, unit.unitFactor);

      for (final batch in batches) {
        if (shortfall <= Decimal.zero || breakCount >= maxBreaks) break;

        while (batch.quantity >= unit.unitFactor && shortfall > Decimal.zero) {
          if (breakCount >= maxBreaks) break;
          final toBreak = shortfall >= unit.unitFactor ? unit.unitFactor : shortfall;
          final result = await _breakOnePackage(
            batch: batch,
            packageSize: toBreak,
            productId: productId,
            warehouseId: warehouseId,
          );
          results.add(result);
          shortfall -= result.brokenQuantity;
          breakCount++;
        }
      }
    }

    if (results.isNotEmpty) {
      await _postPackagingBreakGL(results, productId);
    }

    return results;
  }

  Future<BreakResult> _breakOnePackage({
    required ProductBatch batch,
    required Decimal packageSize,
    required String productId,
    required String warehouseId,
  }) async {
    final actualDeduction = packageSize < batch.quantity ? packageSize : batch.quantity;
    final costPerUnit = (batch.costPrice * packageSize / packageSize).toDecimal(scaleOnInfinitePrecision: 4);

    await (db.update(db.productBatches)..where((b) => b.id.equals(batch.id)))
        .write(ProductBatchesCompanion(
          quantity: Value(batch.quantity - actualDeduction),
        ));

    final newBatchId = const Uuid().v4();
    await db.into(db.productBatches).insert(ProductBatchesCompanion.insert(
          id: Value(newBatchId),
          productId: productId,
          warehouseId: warehouseId,
          batchNumber:
              'BROKEN-${batch.batchNumber}-${DateTime.now().millisecondsSinceEpoch}',
          quantity: Value(actualDeduction),
          initialQuantity: Value(actualDeduction),
          costPrice: Value((batch.costPrice / packageSize).toDecimal(scaleOnInfinitePrecision: 4) * actualDeduction),
          expiryDate: Value(batch.expiryDate),
        ));

    await db.into(db.inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: productId,
            warehouseId: warehouseId,
            batchId: Value(newBatchId),
            quantity: Value(actualDeduction),
            type: 'PACKAGE_BREAK',
            referenceId: 'BREAK-${batch.id}',
          ),
        );

    developer.log(
      'Auto-broke batch ${batch.batchNumber}: $actualDeduction units @ $costPerUnit each',
      name: 'packaging_engine',
    );

    return BreakResult(
      sourceBatchId: batch.id,
      targetBatchId: newBatchId,
      brokenQuantity: actualDeduction,
      costPerUnit: costPerUnit,
    );
  }

  Future<Decimal> _getAvailableQuantity(String productId, String warehouseId) async {
    final batches = await (db.select(db.productBatches)
          ..where((b) => b.productId.equals(productId))
          ..where((b) => b.warehouseId.equals(warehouseId)))
        .get();
    Decimal total = Decimal.zero;
    for (final b in batches) {
      total += b.quantity;
    }
    return total;
  }

  Future<List<ProductBatch>> _getBatchesHavingAtLeast(
    String productId, String warehouseId, Decimal minQty) async {
    return (db.select(db.productBatches)
          ..where((b) => b.productId.equals(productId))
          ..where((b) => b.warehouseId.equals(warehouseId))
          ..where((b) => b.quantity.isBiggerOrEqual(Variable(minQty.toString())))
          ..orderBy([(b) => OrderingTerm(expression: b.expiryDate)]))
        .get();
  }

  Future<void> _postPackagingBreakGL(List<BreakResult> results, String productId) async {
    if (costingService != null) {
      final method = await costingService!.getProductValuationMethod(productId);
      if (method == InventoryValuationMethod.avco) {
        await costingService!.calculateAverageCost(productId);
      }
    }
  }

  Future<String> formatInventoryBalance(String productId, Decimal totalQtyInBase) async {
    try {
      final hierarchy = await getPackagingHierarchy(productId);
      if (hierarchy.isEmpty) return '${totalQtyInBase.toStringAsFixed(0)} حبة';

      final sortedHierarchy = hierarchy.reversed.toList();
      List<String> parts = [];
      Decimal remaining = totalQtyInBase;

      for (var unit in sortedHierarchy) {
        final factor = unit.unitFactor;
        if (factor <= Decimal.one) continue;
        final count = (remaining / factor).toDecimal(scaleOnInfinitePrecision: 0);
        if (count > Decimal.zero) {
          parts.add('${count.toStringAsFixed(0)} ${unit.unitName}');
          remaining -= count * factor;
        }
      }

      if (remaining > Decimal.zero || parts.isEmpty) {
        parts.add('${remaining.toStringAsFixed(0)} حبة');
      }

      return parts.join(' + ');
    } catch (e) {
      return totalQtyInBase.toStringAsFixed(0);
    }
  }

  Future<ProductUnit?> getBestPackagingSuggestion(String productId, Decimal quantityInBase) async {
    final hierarchy = await getPackagingHierarchy(productId);
    ProductUnit? bestMatch;
    for (var unit in hierarchy) {
      if (unit.unitFactor > Decimal.one && unit.unitFactor <= quantityInBase) {
        if (bestMatch == null || unit.unitFactor > bestMatch.unitFactor) {
          bestMatch = unit;
        }
      }
    }
    return bestMatch;
  }

  Future<String?> checkRepackPossibility(String productId, Decimal quantityInBase) async {
    final hierarchy = await getPackagingHierarchy(productId);
    final largeUnits = hierarchy.where((u) => u.unitFactor > Decimal.one).toList();
    if (largeUnits.isEmpty) return null;

    for (var unit in largeUnits.reversed) {
      if (quantityInBase >= unit.unitFactor) {
        return 'يمكنك تجميع ${(quantityInBase / unit.unitFactor).toDecimal(scaleOnInfinitePrecision: 0)} ${unit.unitName}';
      }
    }
    return null;
  }
}
