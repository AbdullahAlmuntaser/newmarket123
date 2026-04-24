import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/core/services/unit_conversion_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late PurchaseService purchaseService;
  late PostingEngine postingEngine;
  late UnitConversionService unitConversionService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    unitConversionService = UnitConversionService(
      productsDao: db.productsDao,
      productUnitsDao: db.productUnitsDao,
    );
    postingEngine = PostingEngine(db);
    purchaseService = PurchaseService(db, unitConversionService, postingEngine);
  });

  tearDown(() async {
    await db.close();
  });

  test('ERP Integration Test: Purchase -> Inventory -> Accounting Flow', () async {
    // 1. Setup Data
    final productId = const Uuid().v4();
    await db.into(db.products).insert(ProductsCompanion.insert(
      id: Value(productId),
      name: 'Test Product',
      sku: 'TP001',
      buyPrice: const Value(10.0),
      sellPrice: const Value(15.0),
      stock: const Value(0.0),
    ));

    await db.into(db.accountingPeriods).insert(AccountingPeriodsCompanion.insert(
      name: 'Jan 2026',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      status: const Value('OPEN'),
    ));

    await db.into(db.postingProfiles).insert(PostingProfilesCompanion.insert(
      operationType: 'purchase',
      accountType: 'INVENTORY',
      side: 'DEBIT',
    ));

    await db.into(db.unitConversions).insert(UnitConversionsCompanion.insert(
      productId: productId,
      unitName: 'pcs',
      factor: 1.0,
      isBaseUnit: const Value(true),
    ));

    // 2. Perform Purchase
    final purchaseId = const Uuid().v4();
    await purchaseService.createPurchase(
      purchaseCompanion: PurchasesCompanion.insert(
        id: Value(purchaseId),
        total: 100.0,
      ),
      itemsCompanions: [
        PurchaseItemsCompanion.insert(
          purchaseId: purchaseId,
          productId: productId,
          quantity: 10.0,
          unitPrice: 10.0,
          price: 100.0,
        )
      ],
      userId: null,
    );

    // 3. Post Purchase
    await purchaseService.postPurchase(purchaseId: purchaseId, userId: null);

    // 4. Verification
    final product = await (db.select(db.products)..where((p) => p.id.equals(productId))).getSingle();
    expect(product.stock, 10.0);
    expect(product.buyPrice, 10.0);
    
    // Check if journal entry exists
    final entries = await (db.select(db.gLEntries)..where((e) => e.referenceId.equals(purchaseId))).get();
    expect(entries.isNotEmpty, true);
  });
}
