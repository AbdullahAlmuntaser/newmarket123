import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/inventory_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late InventoryService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = InventoryService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('InventoryService.getTotalInventoryValue calculates correctly', () async {
    // Add some products with stock and buy price
    final p1 = const Uuid().v4();
    final p2 = const Uuid().v4();

    await db.into(db.products).insert(ProductsCompanion.insert(
      id: Value(p1),
      name: 'Product 1',
      sku: 'SKU1',
      buyPrice: const Value(10.0),
      stock: const Value(5.0),
    ));

    await db.into(db.products).insert(ProductsCompanion.insert(
      id: Value(p2),
      name: 'Product 2',
      sku: 'SKU2',
      buyPrice: const Value(20.0),
      stock: const Value(3.0),
    ));

    final totalValue = await service.getTotalInventoryValue();
    expect(totalValue, (10.0 * 5.0) + (20.0 * 3.0));
  });

  test('InventoryService.watchLowStockProducts filters correctly', () async {
    final p1 = const Uuid().v4();
    final p2 = const Uuid().v4();

    await db.into(db.products).insert(ProductsCompanion.insert(
      id: Value(p1),
      name: 'Product 1',
      sku: 'SKU1',
      stock: const Value(2.0),
      alertLimit: const Value(5.0),
    ));

    await db.into(db.products).insert(ProductsCompanion.insert(
      id: Value(p2),
      name: 'Product 2',
      sku: 'SKU2',
      stock: const Value(10.0),
      alertLimit: const Value(5.0),
    ));

    final lowStock = await service.watchLowStockProducts().first;
    expect(lowStock.length, 1);
    expect(lowStock.first.id, p1);
  });
}
