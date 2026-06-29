import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/core/services/pricing_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/core/services/security_service.dart';

class MockPricingService extends Mock implements PricingService {}

class MockTransactionEngine extends Mock implements TransactionEngine {}

class MockPackagingEngine extends Mock implements PackagingEngine {}

void main() {
  late AppDatabase db;
  late MockPricingService mockPricing;
  late MockTransactionEngine mockTx;
  late MockPackagingEngine mockPkg;

  setUpAll(() {
    SecurityService.useFakeKeyForTesting = true;
    registerFallbackValue(Decimal.zero);
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    mockPricing = MockPricingService();
    mockTx = MockTransactionEngine();
    mockPkg = MockPackagingEngine();
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'AddProductBySku passes isWholesale to pricing and adds item with correct price',
      () async {
    // insert a product into the in-memory DB
    const productId = 'p-test-1';
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: const drift.Value(productId),
          name: 'Test Product',
          sku: 'SKU-TEST',
          buyPrice: drift.Value(Decimal.parse('10')),
          sellPrice: drift.Value(Decimal.parse('20')),
          wholesalePrice: drift.Value(Decimal.parse('15')),
          stock: drift.Value(Decimal.parse('100')),
          maxStock: drift.Value(Decimal.parse('100')),
          unit: const drift.Value('حبة'),
        ));

    // Stub packagingEngine to return empty list for hierarchy
    when(() => mockPkg.getPackagingHierarchy(any()))
        .thenAnswer((_) async => []);

    // Stub pricingService to return a price (e.g., wholesale price fallback)
    when(() => mockPricing.calculatePrice(
          productId: any(named: 'productId'),
          priceListId: any(named: 'priceListId'),
          quantity: any(named: 'quantity'),
          isWholesale: any(named: 'isWholesale'),
        )).thenAnswer((inv) async {
      final args = inv.namedArguments;
      final isWholesale = args[#isWholesale] as bool;
      // If wholesale requested, return wholesalePrice as Decimal
      return isWholesale ? Decimal.parse('15') : Decimal.parse('20');
    });

    // create bloc with real DB but skip init to avoid LoadCategories
    final bloc = PosBloc(db, mockPricing, mockTx, mockPkg, skipInit: true);

    // start with a PosLoaded state with wholesale mode ON
    (bloc as dynamic).emit(PosLoaded(cart: const [], isWholesaleMode: true));

    // Act: add product by SKU
    bloc.add(const AddProductBySku('SKU-TEST'));

    // wait a moment for async handlers
    await Future.delayed(const Duration(milliseconds: 100));

    // Assert: pricingService.calculatePrice was called with isWholesale = true
    verify(() => mockPricing.calculatePrice(
          productId: productId,
          priceListId: null,
          quantity: Decimal.one,
          isWholesale: true,
        )).called(1);

    // The bloc should now have one item in cart with unitPrice = 15
    final currentState = bloc.state as PosLoaded;
    expect(currentState.cart.length, 1);
    final item = currentState.cart.first;
    expect(item.product.id, productId);
    expect(item.unitPrice, Decimal.parse('15'));
    expect(item.isWholesale, true);
  });
}
