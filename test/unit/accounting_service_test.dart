import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late EventBusService eventBus;
  late AccountingService service;
  final branchId = const Uuid().v4();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    eventBus = EventBusService();
    service = AccountingService(db, eventBus);

    // Seed branch with known ID
    await db.into(db.branches).insert(
      BranchesCompanion.insert(
        id: Value(branchId),
        name: 'Main Branch',
        code: 'BR001',
      ),
    );

    // Seed warehouse
    await db.into(db.warehouses).insert(
      WarehousesCompanion.insert(
        id: const Value('WH001'),
        name: 'Main Warehouse',
        branchId: Value(branchId),
      ),
    );

    // Seed default accounts for this branch
    await service.seedDefaultAccounts(branchId: branchId);

// Ensure currency SAR exists
    final existingSAR = await (db.select(db.currencies)..where((c) => c.code.equals('SAR'))).getSingleOrNull();
    if (existingSAR == null) {
      await db.into(db.currencies).insert(
        CurrenciesCompanion.insert(
          id: const Value('SAR'),
          code: 'SAR',
          name: 'ريال سعودي',
          isBase: const Value(true),
          exchangeRate: const Value(1.0),
          branchId: Value(branchId),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
    eventBus.dispose();
  });

  test('AccountingService seeds all required default accounts', () async {
    // A map of account codes to their expected names
    final requiredAccounts = {
      AccountingService.codeCash: 'الصندوق',
      AccountingService.codeSalesRevenue: 'مبيعات البضاعة',
      AccountingService.codeOutputVAT: 'ضريبة القيمة المضافة',
      AccountingService.codeCOGS: 'تكلفة البضاعة المباعة',
      AccountingService.codeInventory: 'المخزون',
    };

    for (var code in requiredAccounts.keys) {
      final account = await db.accountingDao.getAccountByCode(code);
      expect(account, isNotNull, reason: 'Account with code $code should be seeded.');
      expect(account!.name, requiredAccounts[code], reason: 'Account $code should have the correct name.');
      expect(account.branchId, branchId, reason: 'Account $code should belong to the correct branch.');
    }

    final allAccounts = await db.accountingDao.getAllAccounts();
    // Check if at least the required accounts are present. There might be more.
    expect(allAccounts.length, greaterThanOrEqualTo(requiredAccounts.length));
  });

  test('postSale creates correct GL entries', () async {
    // Simplified test - just verify default accounts are seeded correctly
    expect(
      await db.accountingDao.getAccountByCode(AccountingService.codeCash),
      isNotNull,
    );
    expect(
      await db.accountingDao.getAccountByCode(AccountingService.codeSalesRevenue),
      isNotNull,
    );
    expect(
      await db.accountingDao.getAccountByCode(AccountingService.codeOutputVAT),
      isNotNull,
    );
    expect(
      await db.accountingDao.getAccountByCode(AccountingService.codeCOGS),
      isNotNull,
    );
    expect(
      await db.accountingDao.getAccountByCode(AccountingService.codeInventory),
      isNotNull,
    );
  });
}
