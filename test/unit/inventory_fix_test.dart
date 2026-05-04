import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:mockito/mockito.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

class MockAppDatabase extends Mock implements AppDatabase {}
class MockEventBus extends Mock implements EventBusService {}

void main() {
  late TransactionEngine engine;
  late AppDatabase db;
  late EventBusService eventBus;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    eventBus = EventBusService();
    engine = TransactionEngine(db, eventBus);
  });

  tearDown(() async {
    await db.close();
  });

  test('postSaleReturn should update product stock exactly once', () async {
    // Setup initial state: Warehouse, Product with 10 units, Return item with 2 units
    const warehouseId = 'wh_1';
    await db.into(db.warehouses).insert(const WarehousesCompanion(id: Value(warehouseId), name: Value('Main WH')));
    
    const productId = 'prod_1';
    await db.into(db.products).insert(const ProductsCompanion(id: Value(productId), name: Value('Test Product'), sku: Value('SKU1'), stock: Value(10.0)));
    
    const returnId = 'ret_1';
    const saleId = 'sale_1';
    await db.into(db.sales).insert(const SalesCompanion(id: Value(saleId), paymentMethod: Value('cash'), total: Value(100.0), status: Value('POSTED')));

    // Create a batch that belongs to the warehouse to satisfy the Foreign Key constraint in InventoryTransactions
    const batchId = 'batch_1';
    await db.into(db.productBatches).insert(const ProductBatchesCompanion(
      id: Value(batchId),
      productId: Value(productId),
      warehouseId: Value(warehouseId),
      batchNumber: Value('B-001'),
      quantity: Value(10.0),
      costPrice: Value(5.0),
    ));

    await db.into(db.salesReturns).insert(const SalesReturnsCompanion(id: Value(returnId), saleId: Value(saleId), amountReturned: Value(20.0)));
    await db.into(db.salesReturnItems).insert(const SalesReturnItemsCompanion(
      salesReturnId: Value(returnId),
      productId: Value(productId),
      batchId: Value(batchId), // Associate with the batch
      quantity: Value(2.0),
      price: Value(10.0),
    ));

    // Execute
    await engine.postSaleReturn(returnId);

    // Verify
    final updatedProduct = await (db.select(db.products)..where((p) => p.id.equals(productId))).getSingle();
    expect(updatedProduct.stock, 12.0); // 10 + 2, not 14
  });
}


