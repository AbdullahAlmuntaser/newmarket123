import 'package:drift/drift.dart' as drift;
import 'package:supermarket/core/models/inventory/inventory_models.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class InventoryReportService {
  final AppDatabase db;

  InventoryReportService(this.db);

  Stream<List<InventoryTransactionReport>> watchInventoryTransactions({
    String? productId,
    String? warehouseId,
    int limit = 100,
  }) {
    final query = db.select(db.inventoryTransactions).join([
      drift.innerJoin(
        db.products,
        db.products.id.equalsExp(db.inventoryTransactions.productId),
      ),
      drift.leftOuterJoin(
        db.warehouses,
        db.warehouses.id.equalsExp(db.inventoryTransactions.warehouseId),
      ),
    ])
      ..orderBy([
        drift.OrderingTerm(
          expression: db.inventoryTransactions.date,
          mode: drift.OrderingMode.desc,
        ),
      ])
      ..limit(limit);

    if (productId != null) {
      query.where(db.inventoryTransactions.productId.equals(productId));
    }
    if (warehouseId != null) {
      query.where(db.inventoryTransactions.warehouseId.equals(warehouseId));
    }

    return query.watch().map((rows) {
      return rows.map((row) {
        return InventoryTransactionReport(
          transaction: row.readTable(db.inventoryTransactions),
          product: row.readTable(db.products),
          warehouse: row.readTableOrNull(db.warehouses),
        );
      }).toList();
    });
  }

  Stream<List<BatchReport>> watchProductBatches({
    String? productId,
    String? warehouseId,
  }) {
    final query = db.select(db.productBatches).join([
      drift.innerJoin(
        db.products,
        db.products.id.equalsExp(db.productBatches.productId),
      ),
      drift.leftOuterJoin(
        db.warehouses,
        db.warehouses.id.equalsExp(db.productBatches.warehouseId),
      ),
    ]);

    if (productId != null) {
      query.where(db.productBatches.productId.equals(productId));
    }
    if (warehouseId != null) {
      query.where(db.productBatches.warehouseId.equals(warehouseId));
    }

    query.orderBy([
      drift.OrderingTerm(
        expression: db.productBatches.createdAt,
        mode: drift.OrderingMode.desc,
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return BatchReport(
          batch: row.readTable(db.productBatches),
          product: row.readTable(db.products),
          warehouse: row.readTableOrNull(db.warehouses),
        );
      }).toList();
    });
  }

  Future<double> getTotalInventoryValue() {
    return db.calculateTotalInventoryValue();
  }

  Stream<List<Product>> watchLowStockProducts() {
    return db.watchLowStockProducts();
  }

  Stream<List<BatchReport>> watchExpiringSoonBatches({int days = 30}) {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: days));

    final query = db.select(db.productBatches).join([
      drift.innerJoin(
        db.products,
        db.products.id.equalsExp(db.productBatches.productId),
      ),
      drift.leftOuterJoin(
        db.warehouses,
        db.warehouses.id.equalsExp(db.productBatches.warehouseId),
      ),
    ])
      ..where(db.productBatches.expiryDate.isBiggerOrEqual(drift.Variable(now)) &
          db.productBatches.expiryDate.isSmallerOrEqual(
              drift.Variable(threshold)) &
          db.productBatches.quantity
              .isBiggerThan(drift.Constant(Decimal.zero.toString())));

    return query.watch().map((rows) {
      return rows.map((row) {
        return BatchReport(
          batch: row.readTable(db.productBatches),
          product: row.readTable(db.products),
          warehouse: row.readTableOrNull(db.warehouses),
        );
      }).toList();
    });
  }
}
