import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'dart:developer' as developer;

class AutoBreakResult {
  final String productId;
  final List<BreakStep> steps;
  final Decimal totalFreed;

  AutoBreakResult({
    required this.productId,
    required this.steps,
    required this.totalFreed,
  });
}

class BreakStep {
  final String sourceUnit;
  final Decimal sourceQty;
  final String targetUnit;
  final Decimal targetQty;
  final Decimal costPerUnit;

  BreakStep({
    required this.sourceUnit,
    required this.sourceQty,
    required this.targetUnit,
    required this.targetQty,
    required this.costPerUnit,
  });
}

class UnitHierarchyNode {
  final String unitName;
  final Decimal factor;
  final bool isBaseUnit;
  final String? barcode;
  final Decimal? sellPrice;
  final Decimal? buyPrice;

  UnitHierarchyNode({
    required this.unitName,
    required this.factor,
    this.isBaseUnit = false,
    this.barcode,
    this.sellPrice,
    this.buyPrice,
  });
}

class AutoBreakService {
  final AppDatabase db;
  final PackagingEngine packagingEngine;
  final InventoryCostingService? costingService;

  AutoBreakService(this.db, this.packagingEngine, {this.costingService});

  Future<List<UnitHierarchyNode>> getUnitHierarchy(String productId) async {
    final productUnits = await (db.select(db.productUnits)
          ..where((u) => u.productId.equals(productId))
          ..orderBy([
            (u) =>
                OrderingTerm(expression: u.unitFactor, mode: OrderingMode.asc)
          ]))
        .get();

    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingleOrNull();

    final nodes = <UnitHierarchyNode>[];

    if (product != null) {
      nodes.add(UnitHierarchyNode(
        unitName: product.unit,
        factor: Decimal.one,
        isBaseUnit: true,
      ));
    }

    for (final pu in productUnits) {
      nodes.add(UnitHierarchyNode(
        unitName: pu.unitName,
        factor: pu.unitFactor,
        barcode: pu.barcode,
        sellPrice: pu.sellPrice,
        buyPrice: pu.buyPrice,
      ));
    }

    return nodes;
  }

  Future<void> addUnitHierarchy({
    required String productId,
    required String unitName,
    required Decimal factor,
    String? barcode,
    Decimal? sellPrice,
    Decimal? buyPrice,
    Decimal? wholesalePrice,
    Decimal? halfWholesalePrice,
  }) async {
    final existing = await (db.select(db.productUnits)
          ..where((u) => u.productId.equals(productId))
          ..where((u) => u.unitName.equals(unitName)))
        .getSingleOrNull();

    if (existing != null) {
      throw Exception('الوحدة "$unitName" موجودة بالفعل لهذا المنتج');
    }

    if (factor <= Decimal.zero) {
      throw Exception('معامل الوحدة يجب أن يكون أكبر من صفر');
    }

    await db.into(db.productUnits).insert(
          ProductUnitsCompanion.insert(
            productId: productId,
            unitName: unitName,
            unitFactor: Value(factor),
            barcode: Value(barcode),
            sellPrice: Value(sellPrice),
            buyPrice: Value(buyPrice),
            wholesalePrice: Value(wholesalePrice),
            halfWholesalePrice: Value(halfWholesalePrice),
          ),
        );

    developer.log(
      'Added unit hierarchy: $unitName (factor: $factor) for product $productId',
      name: 'auto_break_service',
    );
  }

  Future<void> removeUnitHierarchy({
    required String productId,
    required String unitName,
  }) async {
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingleOrNull();

    if (product != null && product.unit == unitName) {
      throw Exception('لا يمكن حذف الوحدة الأساسية');
    }

    await (db.delete(db.productUnits)
          ..where((u) => u.productId.equals(productId))
          ..where((u) => u.unitName.equals(unitName)))
        .go();

    developer.log(
      'Removed unit hierarchy: $unitName for product $productId',
      name: 'auto_break_service',
    );
  }

  Future<AutoBreakResult> autoBreakForSale({
    required String productId,
    required String warehouseId,
    required Decimal requiredQtyInBase,
  }) async {
    final steps = <BreakStep>[];

    final results = await packagingEngine.autoBreakIfNecessary(
      productId: productId,
      warehouseId: warehouseId,
      requiredQtyInBase: requiredQtyInBase,
    );

    for (final result in results) {
      final sourceUnit = await _getUnitNameForBatch(result.sourceBatchId);
      const targetUnit = 'حبة';

      steps.add(BreakStep(
        sourceUnit: sourceUnit ?? 'وحدة',
        sourceQty: result.brokenQuantity,
        targetUnit: targetUnit,
        targetQty: result.brokenQuantity,
        costPerUnit: result.costPerUnit,
      ));
    }

    final totalFreed = steps.fold<Decimal>(
      Decimal.zero,
      (sum, step) => sum + step.targetQty,
    );

    return AutoBreakResult(
      productId: productId,
      steps: steps,
      totalFreed: totalFreed,
    );
  }

  Future<String?> _getUnitNameForBatch(String batchId) async {
    try {
      final batch = await (db.select(db.productBatches)
            ..where((b) => b.id.equals(batchId)))
          .getSingleOrNull();

      if (batch == null) return null;

      final product = await (db.select(db.products)
            ..where((p) => p.id.equals(batch.productId)))
          .getSingleOrNull();

      return product?.unit;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getInventoryBreakdown({
    required String productId,
    required String warehouseId,
  }) async {
    final batches = await (db.select(db.productBatches)
          ..where((b) => b.productId.equals(productId))
          ..where((b) => b.warehouseId.equals(warehouseId)))
        .get();

    final hierarchy = await getUnitHierarchy(productId);

    Decimal totalBaseQty = Decimal.zero;
    for (final batch in batches) {
      totalBaseQty += batch.quantity;
    }

    final breakdown = <String, Decimal>{};
    Decimal remaining = totalBaseQty;

    for (final node in hierarchy.reversed) {
      if (node.factor <= Decimal.one) continue;
      final count =
          (remaining / node.factor).toDecimal(scaleOnInfinitePrecision: 0);
      if (count > Decimal.zero) {
        breakdown[node.unitName] = count;
        remaining -= count * node.factor;
      }
    }

    if (remaining > Decimal.zero || breakdown.isEmpty) {
      final baseUnitName =
          hierarchy.isNotEmpty ? hierarchy.first.unitName : 'حبة';
      breakdown[baseUnitName] = remaining;
    }

    return {
      'totalBaseQty': totalBaseQty,
      'breakdown': breakdown,
      'hierarchy': hierarchy,
      'batches': batches,
    };
  }

  Future<Decimal> suggestBestUnit({
    required String productId,
    required Decimal quantityInBase,
  }) async {
    final hierarchy = await getUnitHierarchy(productId);
    Decimal bestFactor = Decimal.one;

    for (final node in hierarchy) {
      if (node.factor > Decimal.one &&
          node.factor <= quantityInBase &&
          node.factor > bestFactor) {
        bestFactor = node.factor;
      }
    }

    return bestFactor;
  }

  Future<bool> canRepack({
    required String productId,
    required String warehouseId,
    required String targetUnit,
  }) async {
    final hierarchy = await getUnitHierarchy(productId);
    final targetNode = hierarchy.firstWhere(
      (n) => n.unitName == targetUnit,
      orElse: () => UnitHierarchyNode(unitName: '', factor: Decimal.one),
    );

    if (targetNode.factor <= Decimal.one) return false;

    final batches = await (db.select(db.productBatches)
          ..where((b) => b.productId.equals(productId))
          ..where((b) => b.warehouseId.equals(warehouseId)))
        .get();

    Decimal totalBaseQty = Decimal.zero;
    for (final batch in batches) {
      totalBaseQty += batch.quantity;
    }

    return totalBaseQty >= targetNode.factor;
  }
}
