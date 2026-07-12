import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';

AppDatabase _createDb() => AppDatabase(NativeDatabase.memory());

Future<void> _seedTestData(AppDatabase db) async {
  await db.into(db.accountingPeriods).insert(AccountingPeriodsCompanion.insert(
    id: const Value('open-period'),
    name: 'فترة مفتوحة',
    fiscalYear: DateTime.now().year,
    startDate: DateTime.now().subtract(const Duration(days: 365)),
    endDate: DateTime.now().add(const Duration(days: 365)),
    isClosed: const Value(false),
    status: const Value('OPEN'),
  ));
  await db.into(db.users).insert(UsersCompanion.insert(
    id: const Value('test-user'),
    username: 'test',
    password: 'test',
    role: 'admin',
    fullName: 'Test User',
  ));
  await db.into(db.shifts).insert(ShiftsCompanion.insert(
    id: const Value('shift1'),
    userId: 'test-user',
    isOpen: const Value(true),
  ));
  await db.into(db.warehouses).insert(WarehousesCompanion.insert(
    id: const Value('wh1'),
    name: 'المستودع الرئيسي',
    isDefault: const Value(true),
  ));
  await db.into(db.categories).insert(CategoriesCompanion.insert(
    id: const Value('cat1'),
    name: 'مشروبات',
  ));
  await db.into(db.products).insert(ProductsCompanion.insert(
    id: const Value('prod1'),
    name: 'كولا',
    sku: 'KOLA001',
    buyPrice: Value(Decimal.parse('10')),
    sellPrice: Value(Decimal.parse('15')),
    stock: Value(Decimal.parse('100')),
    categoryId: const Value('cat1'),
  ));
  await db.into(db.customers).insert(CustomersCompanion.insert(
    id: const Value('cust1'),
    name: 'أحمد',
    balance: Value(Decimal.zero),
  ));
  await db.into(db.productBatches).insert(ProductBatchesCompanion.insert(
    id: const Value('batch1'),
    productId: 'prod1',
    warehouseId: 'wh1',
    batchNumber: 'BATCH001',
    quantity: Value(Decimal.parse('100')),
    initialQuantity: Value(Decimal.parse('100')),
    costPrice: Value(Decimal.parse('10')),
  ));
}

void main() {
  group('Accounting Posting - Individual Transactions', () {
    test('Cash sale creates balanced GL entries', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedTestData(db);

      final cashAcc = await db.accountingDao.getAccountByCode('1010');
      final revenueAcc = await db.accountingDao.getAccountByCode('4010');
      final inventoryAcc = await db.accountingDao.getAccountByCode('1040');
      final cogsAcc = await db.accountingDao.getAccountByCode('5010');
      expect(cashAcc, isNotNull);
      expect(revenueAcc, isNotNull);
      expect(inventoryAcc, isNotNull);
      expect(cogsAcc, isNotNull);

      final saleId = const Uuid().v4();
      await db.into(db.sales).insert(SalesCompanion.insert(
        id: Value(saleId),
        customerId: const Value(null),
        total: Decimal.parse('150'),
        tax: Value(Decimal.parse('7.5')),
        paymentMethod: PaymentMethod.cash,
        isCredit: const Value(false),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
        saleId: saleId,
        productId: 'prod1',
        quantity: Decimal.parse('10'),
        price: Decimal.parse('15'),
        unitFactor: Value(Decimal.one),
      ));

      final postingEngine = PostingEngine(db);
      await postingEngine.post(
        type: TransactionType.sale,
        referenceId: saleId,
        context: {
          'amount': Decimal.parse('150'),
          'tax': Decimal.parse('7.5'),
          'cogs': Decimal.parse('100'),
          'paymentMethod': 'cash',
          'description': 'Test Sale',
          'date': DateTime.now(),
        },
      );

      final entries = await db.select(db.gLEntries).get();
      expect(entries.length, 2, reason: 'Should have revenue entry + COGS entry');

      final lines = await db.select(db.gLLines).get();
      expect(lines.length, 5, reason: '3 revenue lines + 2 COGS lines');

      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (final l in lines) {
        totalDebit += l.debit;
        totalCredit += l.credit;
      }
      expect(totalDebit, equals(totalCredit),
          reason: 'Total debits must equal total credits');

      final cashLines = lines.where((l) => l.accountId == cashAcc!.id).toList();
      expect(cashLines.length, 1);
      expect(cashLines.first.debit, equals(Decimal.parse('150')));

      final revenueLines = lines.where((l) => l.accountId == revenueAcc!.id).toList();
      expect(revenueLines.length, 1);
      expect(revenueLines.first.credit, equals(Decimal.parse('142.5')));

      final cogsLines = lines.where((l) => l.accountId == cogsAcc!.id).toList();
      expect(cogsLines.length, 1);
      expect(cogsLines.first.debit, equals(Decimal.parse('100')));

      final invLines = lines.where((l) => l.accountId == inventoryAcc!.id).toList();
      expect(invLines.length, 1);
      expect(invLines.first.credit, equals(Decimal.parse('100')));

      await db.close();
    });

    test('Credit sale uses receivable account', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedTestData(db);

      final arAcc = await db.accountingDao.getAccountByCode('1030');
      expect(arAcc, isNotNull);

      final saleId = const Uuid().v4();
      await db.into(db.sales).insert(SalesCompanion.insert(
        id: Value(saleId),
        customerId: const Value('cust1'),
        total: Decimal.parse('200'),
        tax: Value(Decimal.parse('10')),
        paymentMethod: PaymentMethod.cash,
        isCredit: const Value(true),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
        saleId: saleId,
        productId: 'prod1',
        quantity: Decimal.parse('5'),
        price: Decimal.parse('40'),
        unitFactor: Value(Decimal.one),
      ));

      final postingEngine = PostingEngine(db);
      await postingEngine.post(
        type: TransactionType.sale,
        referenceId: saleId,
        context: {
          'amount': Decimal.parse('200'),
          'tax': Decimal.parse('10'),
          'cogs': Decimal.parse('50'),
          'paymentMethod': 'credit',
          'description': 'Test Credit Sale',
          'customerId': 'cust1',
          'date': DateTime.now(),
        },
      );

      final lines = await db.select(db.gLLines).get();
      final arLines = lines.where((l) => l.accountId == arAcc!.id).toList();
      expect(arLines.length, 1);
      expect(arLines.first.debit, equals(Decimal.parse('200')));

      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (final l in lines) {
        totalDebit += l.debit;
        totalCredit += l.credit;
      }
      expect(totalDebit, equals(totalCredit));

      await db.close();
    });

    test('Purchase creates balanced GL entries', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedTestData(db);

      final inventoryAcc = await db.accountingDao.getAccountByCode('1040');
      final apAcc = await db.accountingDao.getAccountByCode('2010');
      expect(inventoryAcc, isNotNull);
      expect(apAcc, isNotNull);

      final purchaseId = const Uuid().v4();
      await db.into(db.purchases).insert(PurchasesCompanion.insert(
        id: Value(purchaseId),
        supplierId: const Value(null),
        total: Decimal.parse('500'),
        tax: Value(Decimal.parse('25')),
        discount: Value(Decimal.zero),
        isCredit: const Value(true),
      ));

      final postingEngine = PostingEngine(db);
      await postingEngine.post(
        type: TransactionType.purchase,
        referenceId: purchaseId,
        context: {
          'amount': Decimal.parse('500'),
          'tax': Decimal.parse('25'),
          'paymentMethod': 'credit',
          'description': 'Test Purchase',
          'date': DateTime.now(),
        },
      );

      final lines = await db.select(db.gLLines).get();
      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (final l in lines) {
        totalDebit += l.debit;
        totalCredit += l.credit;
      }
      expect(totalDebit, equals(totalCredit));

      final invLines = lines.where((l) => l.accountId == inventoryAcc!.id).toList();
      expect(invLines.length, 1);
      expect(invLines.first.debit, equals(Decimal.parse('475')));

      final apLines = lines.where((l) => l.accountId == apAcc!.id).toList();
      expect(apLines.length, 1);
      expect(apLines.first.credit, equals(Decimal.parse('500')));

      await db.close();
    });

    test('PostingEngine rejects unbalanced entries', () async {
      expect(() {
        PostingEngine.validatePostingLinesRaw([
          GLLinesCompanion.insert(
            entryId: 'e1',
            accountId: 'a1',
            debit: Value(Decimal.parse('100')),
            credit: Value(Decimal.zero),
          ),
          GLLinesCompanion.insert(
            entryId: 'e1',
            accountId: 'a2',
            debit: Value(Decimal.zero),
            credit: Value(Decimal.parse('50')),
          ),
        ]);
      }, throwsA(isA<Exception>()));
    });

    test('PostingEngine rejects empty entries', () async {
      expect(() {
        PostingEngine.validatePostingLinesRaw([]);
      }, throwsA(isA<Exception>()));
    });

    test('PostingEngine rejects zero-amount lines', () async {
      expect(() {
        PostingEngine.validatePostingLinesRaw([
          GLLinesCompanion.insert(
            entryId: 'e1',
            accountId: 'a1',
            debit: Value(Decimal.zero),
            credit: Value(Decimal.zero),
          ),
        ]);
      }, throwsA(isA<Exception>()));
    });

    test('TransactionEngine.postSale creates full GL and stock', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedTestData(db);

      final eventBus = EventBusService();
      final postingEngine = PostingEngine(db);
      final packagingEngine = PackagingEngine(db);
      final engine = TransactionEngine(db, eventBus, postingEngine, packagingEngine);

      final saleId = const Uuid().v4();
      await db.into(db.sales).insert(SalesCompanion.insert(
        id: Value(saleId),
        customerId: const Value(null),
        total: Decimal.parse('150'),
        tax: Value(Decimal.parse('7.5')),
        paymentMethod: PaymentMethod.cash,
        isCredit: const Value(false),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
        saleId: saleId,
        productId: 'prod1',
        quantity: Decimal.parse('10'),
        price: Decimal.parse('15'),
        unitFactor: Value(Decimal.one),
      ));

      await engine.postSale(saleId, userId: 'test-user');

      final postedSale = await (db.select(db.sales)..where((s) => s.id.equals(saleId))).getSingle();
      expect(postedSale.status, DocumentStatus.posted);

      final product = await (db.select(db.products)..where((p) => p.id.equals('prod1'))).getSingle();
      expect(product.stock, equals(Decimal.parse('90')));

      final lines = await db.select(db.gLLines).get();
      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (final l in lines) {
        totalDebit += l.debit;
        totalCredit += l.credit;
      }
      expect(totalDebit, equals(totalCredit));

      await db.close();
    });

    test('TransactionEngine.postPurchase creates full GL and stock', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedTestData(db);

      final eventBus = EventBusService();
      final postingEngine = PostingEngine(db);
      final packagingEngine = PackagingEngine(db);
      final engine = TransactionEngine(db, eventBus, postingEngine, packagingEngine);

      final purchaseId = const Uuid().v4();
      await db.into(db.purchases).insert(PurchasesCompanion.insert(
        id: Value(purchaseId),
        supplierId: const Value(null),
        total: Decimal.parse('300'),
        tax: Value(Decimal.parse('15')),
        discount: Value(Decimal.zero),
        isCredit: const Value(false),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.purchaseItems).insert(PurchaseItemsCompanion.insert(
        purchaseId: purchaseId,
        productId: 'prod1',
        quantity: Decimal.parse('20'),
        unitPrice: Decimal.parse('15'),
        price: Decimal.parse('300'),
        unitFactor: Value(Decimal.one),
      ));

      await engine.postPurchase(purchaseId, userId: 'test-user');

      final product = await (db.select(db.products)..where((p) => p.id.equals('prod1'))).getSingle();
      expect(product.stock, equals(Decimal.parse('120')));

      final lines = await db.select(db.gLLines).get();
      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (final l in lines) {
        totalDebit += l.debit;
        totalCredit += l.credit;
      }
      expect(totalDebit, equals(totalCredit));

      await db.close();
    });
  });
}
