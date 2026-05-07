import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Basic Database Tests', () {
    test('Database connection works', () {
      expect(db, isNotNull);
    });

    test('Can insert and retrieve product', () async {
      const productId = 'test-product-1';
      await db.into(db.products).insert(ProductsCompanion.insert(
        id: const drift.Value(productId),
        name: 'منتج اختبار',
        sku: 'TEST001',
        buyPrice: const drift.Value(50.0),
        sellPrice: const drift.Value(100.0),
        stock: const drift.Value(100.0),
      ));

      final product = await (db.select(db.products)
        ..where((p) => p.id.equals(productId)))
          .getSingle();
      
      expect(product.stock, 100.0);
      expect(product.sellPrice, 100.0);
    });

    test('Can insert and retrieve customer', () async {
      const customerId = 'test-customer-1';
      await db.into(db.customers).insert(CustomersCompanion.insert(
        id: const drift.Value(customerId),
        name: 'عميل اختبار',
        phone: const drift.Value('0123456789'),
      ));

      final customer = await (db.select(db.customers)
        ..where((c) => c.id.equals(customerId)))
          .getSingle();
      
      expect(customer.name, 'عميل اختبار');
    });
  });
}