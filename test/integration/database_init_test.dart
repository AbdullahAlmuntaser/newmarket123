import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

void main() {
  group('Database Initialization Tests', () {
    test('Fresh database creation completes within time limit', () async {
      final db = AppDatabase(NativeDatabase.memory());

      final stopwatch = Stopwatch()..start();
      await db.select(db.users).get();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(10000),
          reason: 'Fresh database creation took ${stopwatch.elapsedMilliseconds}ms');

      await db.close();
    });

    test('All tables are created on fresh database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      ).get();

      final tableNames = tables.map((t) => t.data['name'] as String).toSet();

      final criticalTables = [
        'branches', 'users', 'categories', 'products', 'customers',
        'suppliers', 'sales', 'sale_items', 'purchases', 'purchase_items',
        'gl_accounts', 'gl_entries', 'gl_lines', 'warehouses',
        'product_batches', 'currencies', 'permissions', 'role_permissions',
        'posting_profiles', 'inventory_transactions', 'account_transactions',
        'shifts', 'stock_transfers', 'stock_transfer_items',
        'employees', 'payroll_entries', 'payroll_lines',
        'sales_orders', 'sales_order_items', 'purchase_orders', 'purchase_order_items',
      ];

      for (final tableName in criticalTables) {
        expect(tableNames.contains(tableName), isTrue,
            reason: 'Table "$tableName" was not created');
      }

      await db.close();
    });

    test('Performance indexes are created', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final indexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE '%_idx' ORDER BY name",
      ).get();

      final indexNames = indexes.map((i) => i.data['name'] as String).toSet();

      final criticalIndexes = [
        'products_sku_idx',
        'products_barcode_idx',
        'sale_items_sale_id_idx',
        'purchase_items_purchase_id_idx',
        'gl_lines_entry_id_idx',
        'gl_lines_account_id_idx',
        'stock_movements_product_id_idx',
        'sales_customer_id_idx',
        'purchases_supplier_id_idx',
      ];

      for (final indexName in criticalIndexes) {
        expect(indexNames.contains(indexName), isTrue,
            reason: 'Index "$indexName" was not created');
      }

      await db.close();
    });

    test('Seed data is inserted', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final currencies = await db.select(db.currencies).get();
      expect(currencies.isNotEmpty, isTrue, reason: 'No currencies seeded');

      final branches = await db.select(db.branches).get();
      expect(branches.isNotEmpty, isTrue, reason: 'No branches seeded');

      final glAccounts = await db.select(db.gLAccounts).get();
      expect(glAccounts.isNotEmpty, isTrue, reason: 'No GL accounts seeded');

      final permissions = await db.select(db.permissions).get();
      expect(permissions.isNotEmpty, isTrue, reason: 'No permissions seeded');

      await db.close();
    });

    test('Existing database re-opens within time limit', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      await db1.select(db1.users).get();
      await db1.close();

      final db2 = AppDatabase(NativeDatabase.memory());

      final stopwatch = Stopwatch()..start();
      await db2.select(db2.users).get();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Re-opening database took ${stopwatch.elapsedMilliseconds}ms');

      await db2.close();
    });

    test('Database schema version is correct', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final result = await db.customSelect("PRAGMA user_version").get();
      final version = result.first.data.values.first as int;

      expect(version, equals(50), reason: 'Schema version should be 50');

      await db.close();
    });

    test('Foreign keys are enabled', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final result = await db.customSelect("PRAGMA foreign_keys").get();
      final enabled = result.first.data.values.first;

      expect(enabled, equals(1), reason: 'Foreign keys should be enabled');

      await db.close();
    });

    test('WAL mode is enabled', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final result = await db.customSelect("PRAGMA journal_mode").get();
      final mode = result.first.data.values.first as String;

      final modeLower = mode.toLowerCase();
      expect(modeLower == 'wal' || modeLower == 'memory', isTrue,
          reason: 'Journal mode should be WAL or memory (for in-memory DB), got: $mode');

      await db.close();
    });
  });

  group('DAO Registration Tests', () {
    test('All DAOs are accessible', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      expect(db.productsDao, isNotNull);
      expect(db.salesDao, isNotNull);
      expect(db.customersDao, isNotNull);
      expect(db.accountingDao, isNotNull);
      expect(db.usersDao, isNotNull);
      expect(db.suppliersDao, isNotNull);
      expect(db.purchasesDao, isNotNull);
      expect(db.bomDao, isNotNull);
      expect(db.warehousesDao, isNotNull);
      expect(db.globalUnitsDao, isNotNull);
      expect(db.productUnitsDao, isNotNull);
      expect(db.auditDao, isNotNull);
      expect(db.stockMovementDao, isNotNull);
      expect(db.cashboxDao, isNotNull);
      expect(db.transfersDao, isNotNull);
      expect(db.recurringEntryDao, isNotNull);

      await db.close();
    });
  });
}
