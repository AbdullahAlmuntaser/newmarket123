import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

class BatchInfo {
  final String batchId;
  final String productId;
  final String warehouseId;
  final String batchNumber;
  final double quantity;
  final double costPrice;
  final DateTime? expiryDate;
  final DateTime createdAt;

  BatchInfo({
    required this.batchId,
    required this.productId,
    required this.warehouseId,
    required this.batchNumber,
    required this.quantity,
    required this.costPrice,
    this.expiryDate,
    required this.createdAt,
  });
}

class CostCalculationResult {
  final double totalCost;
  final double averageCost;
  final List<BatchUsage> usedBatches;
  final double remainingQuantity;

  CostCalculationResult({
    required this.totalCost,
    required this.averageCost,
    required this.usedBatches,
    required this.remainingQuantity,
  });
}

class BatchUsage {
  final String batchId;
  final String batchNumber;
  final double quantity;
  final double costPrice;
  final double totalCost;

  BatchUsage({
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    required this.costPrice,
    required this.totalCost,
  });
}

class InventoryValuationItem {
  final String productId;
  final String productName;
  final double totalQuantity;
  final double totalCost;
  final double averageCost;
  final List<BatchSummary> batches;

  InventoryValuationItem({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalCost,
    required this.averageCost,
    required this.batches,
  });
}

class BatchSummary {
  final String batchId;
  final String batchNumber;
  final double quantity;
  final double costPrice;
  final double totalCost;
  final DateTime? expiryDate;

  BatchSummary({
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    required this.costPrice,
    required this.totalCost,
    this.expiryDate,
  });
}

class ProductProfitability {
  final String productId;
  final String productName;
  final double totalSold;
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double profitMargin;

  ProductProfitability({
    required this.productId,
    required this.productName,
    required this.totalSold,
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.profitMargin,
  });
}

enum InventoryTransactionType {
  purchase,
  sale,
  returnIn,
  returnOut,
  transfer,
  adjustment,
  damage,
}

class InventoryCostingService {
  final AppDatabase db;
  late final AuditService _auditService;

  InventoryCostingService(this.db) {
    _auditService = AuditService(db);
  }

  Future<CostCalculationResult> calculateCost({
    required String productId,
    required double quantity,
    String? warehouseId,
  }) async {
    final batches = await _getFefoBatches(productId, warehouseId);

    if (batches.isEmpty) {
      throw Exception('لا توجد batches للمنتج');
    }

    double remainingToDeduct = quantity;
    double totalCost = 0;
    final usedBatches = <BatchUsage>[];

    for (var batch in batches) {
      if (remainingToDeduct <= 0) break;
      if (batch.quantity <= 0) continue;

      final qtyFromBatch = remainingToDeduct >= batch.quantity
          ? batch.quantity
          : remainingToDeduct;

      final cost = qtyFromBatch * batch.costPrice;
      totalCost += cost;
      remainingToDeduct -= qtyFromBatch;

      usedBatches.add(
        BatchUsage(
          batchId: batch.batchId,
          batchNumber: batch.batchNumber,
          quantity: qtyFromBatch,
          costPrice: batch.costPrice,
          totalCost: cost,
        ),
      );
    }

    if (remainingToDeduct > 0.001) {
      throw Exception('المخزون غير كافٍ. المتبقي: $remainingToDeduct');
    }

    final averageCost = quantity > 0 ? totalCost / quantity : 0.0;

    return CostCalculationResult(
      totalCost: totalCost,
      averageCost: averageCost,
      usedBatches: usedBatches,
      remainingQuantity: remainingToDeduct.abs(),
    );
  }

  Future<List<BatchInfo>> _getFefoBatches(
    String productId,
    String? warehouseId,
  ) async {
    var query = db.select(db.productBatches)
      ..where((b) => b.productId.equals(productId))
      ..where((b) => b.quantity.isBiggerThanValue(0))
      ..orderBy([
        (b) => OrderingTerm(expression: b.expiryDate, mode: OrderingMode.asc),
        (b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.asc),
      ]);

    if (warehouseId != null) {
      query = query..where((b) => b.warehouseId.equals(warehouseId));
    }

    final batches = await query.get();

    return batches
        .map(
          (b) => BatchInfo(
            batchId: b.id,
            productId: b.productId,
            warehouseId: b.warehouseId,
            batchNumber: b.batchNumber,
            quantity: b.quantity,
            costPrice: b.costPrice,
            expiryDate: b.expiryDate,
            createdAt: b.createdAt,
          ),
        )
        .toList();
  }

  Future<void> deductFromInventory({
    required String productId,
    required double quantity,
    required String referenceId,
    required InventoryTransactionType type,
    String? warehouseId,
  }) async {
    final costResult = await calculateCost(
      productId: productId,
      quantity: quantity,
      warehouseId: warehouseId,
    );

    for (var usage in costResult.usedBatches) {
      final batch = await (db.select(
        db.productBatches,
      )..where((b) => b.id.equals(usage.batchId))).getSingle();

      await (db.update(
        db.productBatches,
      )..where((b) => b.id.equals(usage.batchId))).write(
        ProductBatchesCompanion(
          quantity: Value(batch.quantity - usage.quantity),
        ),
      );

      await _recordInventoryTransaction(
        productId: productId,
        warehouseId: batch.warehouseId,
        batchId: usage.batchId,
        quantity: -usage.quantity,
        type: type,
        referenceId: referenceId,
      );
    }

    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingle();
    await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(stock: Value(product.stock - quantity)),
    );

    await _auditService.logCreate(
      'InventoryDeduction',
      referenceId,
      details:
          'خصم من المخزون: $quantity × ${costResult.averageCost.toStringAsFixed(2)} = ${costResult.totalCost.toStringAsFixed(2)}',
    );
  }

  Future<void> addToInventory({
    required String productId,
    required double quantity,
    required double costPrice,
    required String referenceId,
    required InventoryTransactionType type,
    required String warehouseId,
  }) async {
    final batchId = const Uuid().v4();
    final batchNumber = 'PUR-${referenceId.substring(0, 8)}';

    await db
        .into(db.productBatches)
        .insert(
          ProductBatchesCompanion.insert(
            id: Value(batchId),
            productId: productId,
            warehouseId: warehouseId,
            batchNumber: batchNumber,
            quantity: Value(quantity),
            initialQuantity: Value(quantity),
            costPrice: Value(costPrice),
            syncStatus: const Value(1),
          ),
        );

    await _recordInventoryTransaction(
      productId: productId,
      warehouseId: warehouseId,
      batchId: batchId,
      quantity: quantity,
      type: type,
      referenceId: referenceId,
    );

    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingle();
    await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        stock: Value(product.stock + quantity),
        buyPrice: Value(costPrice),
      ),
    );

    await _auditService.logCreate(
      'InventoryAddition',
      referenceId,
      details: ' إضافة للمخزون: $quantity × $costPrice',
    );
  }

  Future<void> returnToInventory({
    required String productId,
    required double quantity,
    required String originalSaleId,
    required String returnId,
  }) async {
    final originalSaleItems =
        await (db.select(db.saleItems)
              ..where((si) => si.saleId.equals(originalSaleId))
              ..where((si) => si.productId.equals(productId)))
            .get();

    if (originalSaleItems.isEmpty) {
      throw Exception('عنصر البيع الأصلي غير موجود');
    }

    var batches = await _getFefoBatches(productId, null);
    if (batches.isEmpty) {
      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();
      await addToInventory(
        productId: productId,
        quantity: quantity,
        costPrice: product.buyPrice,
        referenceId: returnId,
        type: InventoryTransactionType.returnIn,
        warehouseId: '',
      );
      return;
    }

    final latestBatch = batches.first;
    await (db.update(
      db.productBatches,
    )..where((b) => b.id.equals(latestBatch.batchId))).write(
      ProductBatchesCompanion(quantity: Value(latestBatch.quantity + quantity)),
    );

    await _recordInventoryTransaction(
      productId: productId,
      warehouseId: latestBatch.warehouseId,
      batchId: latestBatch.batchId,
      quantity: quantity,
      type: InventoryTransactionType.returnIn,
      referenceId: returnId,
    );

    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingle();
    await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(stock: Value(product.stock + quantity)),
    );

    await _auditService.logCreate(
      'InventoryReturn',
      returnId,
      details: 'مردود للمخزون: $quantity',
    );
  }

  Future<void> adjustInventory({
    required String productId,
    required double newQuantity,
    required String adjustmentId,
    required String note,
    String? warehouseId,
  }) async {
    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingle();
    final difference = newQuantity - product.stock;

    if (difference == 0) return;

    if (difference > 0) {
      await addToInventory(
        productId: productId,
        quantity: difference.abs(),
        costPrice: product.buyPrice,
        referenceId: adjustmentId,
        type: InventoryTransactionType.adjustment,
        warehouseId: warehouseId ?? '',
      );
    } else {
      await deductFromInventory(
        productId: productId,
        quantity: difference.abs(),
        referenceId: adjustmentId,
        type: InventoryTransactionType.damage,
        warehouseId: warehouseId,
      );
    }

    await _auditService.logCreate(
      'InventoryAdjustment',
      adjustmentId,
      details: 'تسوية مخزون: $note. الفرق: ${difference.toStringAsFixed(2)}',
    );
  }

  Future<void> _recordInventoryTransaction({
    required String productId,
    required String warehouseId,
    required String batchId,
    required double quantity,
    required InventoryTransactionType type,
    required String referenceId,
  }) async {
    await db
        .into(db.inventoryTransactions)
        .insert(
          InventoryTransactionsCompanion.insert(
            productId: productId,
            warehouseId: warehouseId,
            batchId: Value(batchId),
            quantity: quantity,
            type: type.name,
            referenceId: referenceId,
          ),
        );
  }

  Future<List<InventoryValuationItem>> getInventoryValuation({
    String? warehouseId,
  }) async {
    final products = await (db.select(
      db.products,
    )..where((p) => p.stock.isBiggerThanValue(0))).get();

    final List<InventoryValuationItem> valuation = [];

    for (var product in products) {
      var query = db.select(db.productBatches)
        ..where((b) => b.productId.equals(product.id))
        ..where((b) => b.quantity.isBiggerThanValue(0));

      if (warehouseId != null) {
        query = query..where((b) => b.warehouseId.equals(warehouseId));
      }

      final batches = await query.get();

      if (batches.isEmpty) continue;

      double totalCost = 0;
      double totalQty = 0;
      final batchSummaries = <BatchSummary>[];

      for (var batch in batches) {
        final qty = batch.quantity;
        final cost = batch.costPrice;
        totalQty += qty;
        totalCost += qty * cost;

        batchSummaries.add(
          BatchSummary(
            batchId: batch.id,
            batchNumber: batch.batchNumber,
            quantity: qty,
            costPrice: cost,
            totalCost: qty * cost,
            expiryDate: batch.expiryDate,
          ),
        );
      }

      valuation.add(
        InventoryValuationItem(
          productId: product.id,
          productName: product.name,
          totalQuantity: totalQty,
          totalCost: totalCost,
          averageCost: totalQty > 0 ? totalCost / totalQty : 0.0,
          batches: batchSummaries,
        ),
      );
    }

    valuation.sort((a, b) => b.totalCost.compareTo(a.totalCost));
    return valuation;
  }

  Future<double> getTotalInventoryValue({String? warehouseId}) async {
    final valuation = await getInventoryValuation(warehouseId: warehouseId);
    double total = 0;
    for (var item in valuation) {
      total += item.totalCost;
    }
    return total;
  }

  Future<List<ProductProfitability>> getProductProfitability({
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
  }) async {
    final start = startDate ?? DateTime(2000);
    final end = endDate ?? DateTime.now();

    List<Product> products;
    if (productId != null) {
      products = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).get();
    } else {
      products = await db.select(db.products).get();
    }

    final List<ProductProfitability> profitability = [];

    for (var product in products) {
      final List<SaleItem> itemsWithSales = [];

      final allSaleItems = await (db.select(
        db.saleItems,
      )..where((si) => si.productId.equals(product.id))).get();

      for (var item in allSaleItems) {
        final sale =
            await (db.select(db.sales)
                  ..where((s) => s.id.equals(item.saleId))
                  ..where((s) => s.createdAt.isBetweenValues(start, end)))
                .getSingleOrNull();
        if (sale != null) {
          itemsWithSales.add(item);
        }
      }

      if (itemsWithSales.isEmpty) continue;

      double totalSold = 0;
      double totalRevenue = 0;
      double totalCost = 0;

      for (var item in itemsWithSales) {
        final qty = item.quantity * item.unitFactor;
        totalSold += qty;
        totalRevenue += qty * item.price;

        try {
          final costResult = await calculateCost(
            productId: product.id,
            quantity: qty,
          );
          totalCost += costResult.totalCost;
        } catch (e) {
          totalCost += qty * product.buyPrice;
        }
      }

      if (totalSold == 0) continue;

      final grossProfit = totalRevenue - totalCost;
      final profitMargin = totalRevenue > 0 ? grossProfit / totalRevenue : 0.0;

      profitability.add(
        ProductProfitability(
          productId: product.id,
          productName: product.name,
          totalSold: totalSold,
          totalRevenue: totalRevenue,
          totalCost: totalCost,
          grossProfit: grossProfit,
          profitMargin: profitMargin,
        ),
      );
    }

    profitability.sort((a, b) => b.grossProfit.compareTo(a.grossProfit));
    return profitability;
  }

  Future<double> calculateCogs({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime(2000);
    final end = endDate ?? DateTime.now();

    final sales = await (db.select(
      db.sales,
    )..where((s) => s.createdAt.isBetweenValues(start, end))).get();

    double totalCogs = 0;

    for (var sale in sales) {
      final items = await (db.select(
        db.saleItems,
      )..where((si) => si.saleId.equals(sale.id))).get();

      for (var item in items) {
        final qty = item.quantity * item.unitFactor;

        try {
          final costResult = await calculateCost(
            productId: item.productId,
            quantity: qty,
          );
          totalCogs += costResult.totalCost;
        } catch (e) {
          final product = await (db.select(
            db.products,
          )..where((p) => p.id.equals(item.productId))).getSingleOrNull();
          if (product != null) {
            totalCogs += qty * product.buyPrice;
          }
        }
      }
    }

    return totalCogs;
  }
}
