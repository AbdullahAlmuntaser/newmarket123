import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late AccountingService service;
  late EventBusService eventBus;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    eventBus = EventBusService();
    service = AccountingService(db, eventBus);
    await service.seedDefaultAccounts();

    // Seed default currency
    await db
        .into(db.currencies)
        .insert(
          CurrenciesCompanion.insert(
            id: const Value('USD'),
            code: 'USD',
            name: 'US Dollar',
          ),
        );
  });

  tearDown(() async {
    await db.close();
    eventBus.dispose();
  });

  test('AccountingService seeds default accounts', () async {
    final accounts = await db.accountingDao.getAllAccounts();
    expect(accounts, isNotEmpty);

    final cashAccount = await db.accountingDao.getAccountByCode(
      AccountingService.codeCash,
    );
    expect(cashAccount, isNotNull);
    expect(cashAccount!.name, 'الصندوق');
  });

  test('postSale creates correct GL entries', () async {
    final saleId = const Uuid().v4();
    final sale = Sale(
      id: saleId,
      total: 115.0,
      tax: 15.0,
      discount: 0.0,
      paymentMethod: 'Cash',
      isCredit: false,
      status: 'POSTED',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 1,
      currencyId: 'USD',
      exchangeRate: 1.0,
      saleType: 'retail',
    );

    // Mock products for COGS
    final productId = const Uuid().v4();
    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: Value(productId),
            name: 'Test Product',
            sku: 'TEST-123',
            buyPrice: const Value(50.0),
            sellPrice: const Value(100.0),
            stock: const Value(10.0),
          ),
        );

    // MUST insert a batch for COGS calculation to work (AccountingService uses batches)
    final warehouseId = const Uuid().v4();
    await db
        .into(db.warehouses)
        .insert(
          WarehousesCompanion.insert(
            id: Value(warehouseId),
            name: 'Main Warehouse',
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(1),
          ),
        );

    await db
        .into(db.productBatches)
        .insert(
          ProductBatchesCompanion.insert(
            id: Value(const Uuid().v4()),
            productId: productId,
            warehouseId: warehouseId,
            batchNumber: 'BATCH-001',
            quantity: const Value(10.0),
            costPrice: const Value(50.0),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(1),
          ),
        );

    final saleItems = [
      SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        productId: productId,
        quantity: 1.0,
        price: 100.0,
        unitName: 'حبة',
        unitFactor: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 1,
      ),
    ];

    await service.postSale(sale, saleItems);

    // Check Revenue Entry
    final entries = await db.accountingDao.getGLEntriesInDateRange(
      DateTime.now().subtract(const Duration(minutes: 1)),
      DateTime.now().add(const Duration(minutes: 1)),
    );

    // Should have 2 entries: 1 for Revenue/Tax, 1 for COGS
    expect(entries.length, 2);

    final revenueEntry = entries.firstWhere((e) => e.referenceType == 'SALE');
    final lines = await db.accountingDao.getLinesForEntry(revenueEntry.id);

    expect(
      lines.length,
      3,
    ); // Cash (Debit), Revenue (Credit), Output VAT (Credit)

    final cashLine = lines.firstWhere(
      (l) => l.account.code == AccountingService.codeCash,
    );
    expect(cashLine.line.debit, 115.0);
    expect(cashLine.line.credit, 0.0);

    final revLine = lines.firstWhere(
      (l) => l.account.code == AccountingService.codeSalesRevenue,
    );
    expect(revLine.line.credit, 100.0);

    final taxLine = lines.firstWhere(
      (l) => l.account.code == AccountingService.codeOutputVAT,
    );
    expect(taxLine.line.credit, 15.0);

    // Check COGS Entry
    final cogsEntry = entries.firstWhere((e) => e.referenceType == 'COGS');
    final cogsLines = await db.accountingDao.getLinesForEntry(cogsEntry.id);
    expect(cogsLines.length, 2);

    final cogsLine = cogsLines.firstWhere(
      (l) => l.account.code == AccountingService.codeCOGS,
    );
    expect(cogsLine.line.debit, 50.0);
  });
}
