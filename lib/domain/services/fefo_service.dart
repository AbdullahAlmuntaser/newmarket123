import 'package:sqflite/sqflite.dart';

class FefoService {
  final Database database;

  FefoService({required this.database});

  /// Get products sorted by FEFO (First Expired First Out)
  Future<List<Map<String, dynamic>>> getProductsByFEFO({
    required int productId,
    required int warehouseId,
  }) async {
    final result = await database.query(
      'inventory_batches',
      where: 'product_id = ? AND warehouse_id = ? AND quantity > 0',
      whereArgs: [productId, warehouseId],
      orderBy: 'expiry_date ASC',
    );
    return result;
  }

  /// Allocate stock based on FEFO principle
  Future<List<Map<String, dynamic>>> allocateStockFEFO({
    required int productId,
    required int warehouseId,
    required double quantityNeeded,
  }) async {
    final batches = await getProductsByFEFO(
      productId: productId,
      warehouseId: warehouseId,
    );

    List<Map<String, dynamic>> allocatedBatches = [];
    double remainingQuantity = quantityNeeded;

    for (var batch in batches) {
      if (remainingQuantity <= 0) break;

      double availableQty = (batch['quantity'] as num).toDouble();
      double allocateFromBatch = remainingQuantity > availableQty 
          ? availableQty 
          : remainingQuantity;

      allocatedBatches.add({
        'batch_id': batch['id'],
        'quantity': allocateFromBatch,
        'expiry_date': batch['expiry_date'],
      });

      remainingQuantity -= allocateFromBatch;
    }

    if (remainingQuantity > 0) {
      throw Exception('Insufficient stock. Still need: $remainingQuantity');
    }

    return allocatedBatches;
  }

  /// Check if product is expiring soon
  Future<List<Map<String, dynamic>>> getExpiringProducts({
    required int warehouseId,
    int daysThreshold = 30,
  }) async {
    final expiryDate = DateTime.now().add(Duration(days: daysThreshold));
    
    final result = await database.query(
      'inventory_batches',
      where: 'warehouse_id = ? AND expiry_date <= ? AND quantity > 0',
      whereArgs: [warehouseId, expiryDate.toIso8601String()],
      orderBy: 'expiry_date ASC',
    );
    
    return result;
  }

  /// Get expired products
  Future<List<Map<String, dynamic>>> getExpiredProducts({
    required int warehouseId,
  }) async {
    final now = DateTime.now();
    
    final result = await database.query(
      'inventory_batches',
      where: 'warehouse_id = ? AND expiry_date < ? AND quantity > 0',
      whereArgs: [warehouseId, now.toIso8601String()],
      orderBy: 'expiry_date ASC',
    );
    
    return result;
  }
}
