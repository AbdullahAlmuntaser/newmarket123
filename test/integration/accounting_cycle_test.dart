import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/core/services/financial_report_service.dart';
import 'package:supermarket/core/services/return_service.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';

AppDatabase _createDb() => AppDatabase(NativeDatabase.memory());

Future<void> _seedFullTestData(AppDatabase db) async {
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
    name: 'مواد غذائية',
  ));
  await db.into(db.products).insert(ProductsCompanion.insert(
    id: const Value('prod1'),
    name: 'سكر',
    sku: 'SUGAR001',
    buyPrice: Value(Decimal.parse('5')),
    sellPrice: Value(Decimal.parse('8')),
    stock: Value(Decimal.parse('500')),
    categoryId: const Value('cat1'),
  ));
  await db.into(db.customers).insert(CustomersCompanion.insert(
    id: const Value('cust1'),
    name: 'شركة الأمل',
    balance: Value(Decimal.zero),
    creditLimit: Value(Decimal.parse('10000')),
  ));
  await db.into(db.suppliers).insert(SuppliersCompanion.insert(
    id: const Value('supp1'),
    name: 'شركة التموين',
    balance: Value(Decimal.zero),
  ));
  await db.into(db.productBatches).insert(ProductBatchesCompanion.insert(
    id: const Value('batch1'),
    productId: 'prod1',
    warehouseId: 'wh1',
    batchNumber: 'INIT001',
    quantity: Value(Decimal.parse('500')),
    initialQuantity: Value(Decimal.parse('500')),
    costPrice: Value(Decimal.parse('5')),
  ));
}

void main() {
  group('Full Accounting Cycle', () {
    test('Complete sale → GL → Trial Balance = 0', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedFullTestData(db);

      final eventBus = EventBusService();
      final postingEngine = PostingEngine(db);
      final packagingEngine = PackagingEngine(db);
      final engine = TransactionEngine(db, eventBus, postingEngine, packagingEngine);
      final reports = FinancialReportService(db);

      // 1. Create and post a cash sale
      final saleId = const Uuid().v4();
      await db.into(db.sales).insert(SalesCompanion.insert(
        id: Value(saleId),
        customerId: const Value(null),
        total: Decimal.parse('400'),
        tax: Value(Decimal.parse('20')),
        paymentMethod: PaymentMethod.cash,
        isCredit: const Value(false),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
        saleId: saleId,
        productId: 'prod1',
        quantity: Decimal.parse('50'),
        price: Decimal.parse('8'),
        unitFactor: Value(Decimal.one),
      ));
      await engine.postSale(saleId, userId: 'test-user');

      // 2. Create and post a credit sale
      const creditSaleId = 'credit-sale-1';
      await db.into(db.sales).insert(SalesCompanion.insert(
        id: const Value(creditSaleId),
        customerId: const Value('cust1'),
        total: Decimal.parse('800'),
        tax: Value(Decimal.parse('40')),
        paymentMethod: PaymentMethod.cash,
        isCredit: const Value(true),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
        saleId: creditSaleId,
        productId: 'prod1',
        quantity: Decimal.parse('100'),
        price: Decimal.parse('8'),
        unitFactor: Value(Decimal.one),
      ));
      await engine.postSale(creditSaleId, userId: 'test-user');

      // 3. Verify trial balance = 0
      final trialBalance = await db.accountingDao.getTrialBalance();
      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (final item in trialBalance) {
        totalDebit += item.totalDebit;
        totalCredit += item.totalCredit;
      }
      expect(totalDebit, equals(totalCredit),
          reason: 'Trial balance must be zero after all entries');

      // 4. Verify stock deducted
      final product = await (db.select(db.products)..where((p) => p.id.equals('prod1'))).getSingle();
      expect(product.stock, equals(Decimal.parse('350')),
          reason: '500 - 50 - 100 = 350');

      // 5. Verify income statement shows revenue
      final incomeStmt = await reports.getIncomeStatement(
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(incomeStmt.totalRevenue, greaterThan(Decimal.zero));
      expect(incomeStmt.totalRevenue - incomeStmt.totalExpense, greaterThan(Decimal.zero));

      await db.close();
    });

    test('Purchase → Sale → Return → GL integrity', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedFullTestData(db);

      final eventBus = EventBusService();
      final postingEngine = PostingEngine(db);
      final packagingEngine = PackagingEngine(db);
      final engine = TransactionEngine(db, eventBus, postingEngine, packagingEngine);
      final returnService = ReturnService(db);

      // 1. Post a purchase
      final purchaseId = const Uuid().v4();
      await db.into(db.purchases).insert(PurchasesCompanion.insert(
        id: Value(purchaseId),
        supplierId: const Value('supp1'),
        total: Decimal.parse('1000'),
        tax: Value(Decimal.parse('50')),
        discount: Value(Decimal.zero),
        isCredit: const Value(true),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.purchaseItems).insert(PurchaseItemsCompanion.insert(
        purchaseId: purchaseId,
        productId: 'prod1',
        quantity: Decimal.parse('200'),
        unitPrice: Decimal.parse('5'),
        price: Decimal.parse('1000'),
        unitFactor: Value(Decimal.one),
      ));
      await engine.postPurchase(purchaseId, userId: 'test-user');

      // 2. Post a sale
      final saleId = const Uuid().v4();
      await db.into(db.sales).insert(SalesCompanion.insert(
        id: Value(saleId),
        customerId: const Value('cust1'),
        total: Decimal.parse('600'),
        tax: Value(Decimal.parse('30')),
        paymentMethod: PaymentMethod.cash,
        isCredit: const Value(true),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
        saleId: saleId,
        productId: 'prod1',
        quantity: Decimal.parse('60'),
        price: Decimal.parse('10'),
        unitFactor: Value(Decimal.one),
      ));
      await engine.postSale(saleId, userId: 'test-user');

      // 3. Process a sale return (10 items returned)
      final beforeReturnProduct = await (db.select(db.products)
        ..where((p) => p.id.equals('prod1'))).getSingle();
      expect(beforeReturnProduct.stock, equals(Decimal.parse('640')));

      await returnService.processSalesReturn(
        saleId: saleId,
        items: [
          ReturnItemData(
            productId: 'prod1',
            quantity: 10,
            price: 10,
          ),
        ],
        reason: 'تلف',
        userId: 'test-user',
      );

      // 4. Verify stock returned
      final afterReturnProduct = await (db.select(db.products)
        ..where((p) => p.id.equals('prod1'))).getSingle();
      expect(afterReturnProduct.stock, equals(Decimal.parse('650')),
          reason: '640 + 10 returned = 650');

      // 5. Verify GL entries balance
      final lines = await db.select(db.gLLines).get();
      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (final l in lines) {
        totalDebit += l.debit;
        totalCredit += l.credit;
      }
      expect(totalDebit, equals(totalCredit),
          reason: 'All GL entries must balance after purchase + sale + return');

      await db.close();
    });

    test('Balance Sheet balances (Assets = Liabilities + Equity)', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedFullTestData(db);

      final eventBus = EventBusService();
      final postingEngine = PostingEngine(db);
      final packagingEngine = PackagingEngine(db);
      final engine = TransactionEngine(db, eventBus, postingEngine, packagingEngine);
      final reports = FinancialReportService(db);

      // Post a cash sale (creates revenue)
      const saleId = 'bs-sale-1';
      await db.into(db.sales).insert(SalesCompanion.insert(
        id: const Value(saleId),
        customerId: const Value(null),
        total: Decimal.parse('160'),
        tax: Value(Decimal.parse('8')),
        paymentMethod: PaymentMethod.cash,
        isCredit: const Value(false),
        warehouseId: const Value('wh1'),
      ));
      await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
        saleId: saleId,
        productId: 'prod1',
        quantity: Decimal.parse('20'),
        price: Decimal.parse('8'),
        unitFactor: Value(Decimal.one),
      ));
      await engine.postSale(saleId, userId: 'test-user');

      // Balance sheet
      final bs = await reports.getBalanceSheet();
      expect(bs.totalAssets, equals(bs.totalLiabilities + bs.totalEquity),
          reason: 'Assets must equal Liabilities + Equity');

      await db.close();
    });

    test('Period closing blocks new transactions', () async {
      final db = _createDb();
      await db.seedDefaultGLAccounts();
      await _seedFullTestData(db);

      // Create an accounting period and close it
      final now = DateTime.now();
      await db.into(db.accountingPeriods).insert(AccountingPeriodsCompanion.insert(
        id: const Value('closed-period'),
        name: 'فترة مغلقة',
        fiscalYear: DateTime.now().year,
        startDate: now.subtract(const Duration(days: 60)),
        endDate: now.add(const Duration(days: 30)),
        isClosed: const Value(true),
        status: const Value('CLOSED'),
      ));

      // Verify period is closed
      final isClosed = await db.accountingDao.isDateInClosedPeriod(now);
      expect(isClosed, isTrue);

      // Posting should fail in closed period
      final postingEngine = PostingEngine(db);
      expect(
        () => postingEngine.post(
          type: TransactionType.sale,
          referenceId: 'fail-sale',
          context: {
            'amount': Decimal.parse('100'),
            'tax': Decimal.zero,
            'cogs': Decimal.zero,
            'paymentMethod': 'cash',
            'date': now,
          },
        ),
        throwsA(isA<Exception>()),
      );

      await db.close();
    });
  });
}
