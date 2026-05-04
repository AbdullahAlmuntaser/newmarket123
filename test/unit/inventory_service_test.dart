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
    await db.delete(db.products).go();
    await db.delete(db.warehouses).go();
    service = InventoryService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('InventoryService.getTotalInventoryValue - skipped', () async {
    // Skipped - requires complex batch setup
  }, skip: true);

  test('InventoryService.watchLowStockProducts filters correctly', () async {
    final p1 = const Uuid().v4();

    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: Value(p1),
            name: 'Product 1',
            sku: 'SKU1',
            stock: const Value(2.0),
            alertLimit: const Value(5.0),
          ),
        );

    final lowStockStream = service.watchLowStockProducts().first;
    final lowStockProducts = await lowStockStream;

    expect(lowStockProducts.length, 1);
    expect(lowStockProducts.first.id, p1);
  });
}