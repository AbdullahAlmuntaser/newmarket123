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

  group('Purchase Flow Tests', () {
    test('إنشاء مورد في قاعدة البيانات', () async {
      const supplierId = 'test-supplier-1';
      await db.into(db.suppliers).insert(SuppliersCompanion.insert(
        id: const drift.Value(supplierId),
        name: 'مورد اختبار',
        phone: const drift.Value('0123456789'),
      ));

      final supplier = await (db.select(db.suppliers)
        ..where((s) => s.id.equals(supplierId)))
          .getSingle();
      
      expect(supplier.name, 'مورد اختبار');
    });

    test('إنشاء مستودع في قاعدة البيانات', () async {
      const warehouseId = 'test-warehouse-1';
      await db.into(db.warehouses).insert(WarehousesCompanion.insert(
        id: const drift.Value(warehouseId),
        name: 'المستودع الرئيسي',
      ));

      final warehouse = await (db.select(db.warehouses)
        ..where((w) => w.id.equals(warehouseId)))
          .getSingle();
      
      expect(warehouse.name, 'المستودع الرئيسي');
    });

    test('إنشاء صنف مع الرصيد الابتدائي', () async {
      const productId = 'test-product-1';
      await db.into(db.products).insert(ProductsCompanion.insert(
        id: const drift.Value(productId),
        name: 'صنف اختبار',
        sku: 'P001',
        buyPrice: const drift.Value(50.0),
        sellPrice: const drift.Value(100.0),
        stock: const drift.Value(0.0),
      ));

      final product = await (db.select(db.products)
        ..where((p) => p.id.equals(productId)))
          .getSingle();
      
      expect(product.stock, 0.0);
    });
  });
}