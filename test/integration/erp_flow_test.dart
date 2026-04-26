import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/data/datasources/local/daos/stock_movement_dao.dart';

void main() {
  late AppDatabase db;
  late PurchaseService purchaseService;
  late PostingEngine postingEngine;
  late InventoryCostingService inventoryCostingService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    postingEngine = PostingEngine(db);
    inventoryCostingService = InventoryCostingService(StockMovementDao(db));
    purchaseService = PurchaseService(
      db,
      postingEngine,
      inventoryCostingService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('ERP Integration Test: Purchase Flow', () async {
    final supplierId = const Uuid().v4();
    final productId = const Uuid().v4();
    final warehouseId = const Uuid().v4();

    await db
        .into(db.warehouses)
        .insert(
          WarehousesCompanion.insert(
            id: Value(warehouseId),
            name: 'Test Warehouse',
            isDefault: const Value(true),
          ),
        );

    await db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            id: Value(supplierId),
            name: 'Test Supplier',
          ),
        );

    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: Value(productId),
            name: 'Test Product',
            sku: 'TP001',
            unit: const Value('pcs'),
            buyPrice: const Value(10.0),
            sellPrice: const Value(15.0),
            stock: const Value(0.0),
          ),
        );

    final purchase = await purchaseService.createPurchase(
      supplierId: supplierId,
      items: [],
      total: 0.0,
    );

    expect(purchase.id, isNotEmpty);
  });
}
