import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:decimal/decimal.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/core/services/pricing_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class MockAppDatabase extends Mock implements AppDatabase {}
class MockPricingService extends Mock implements PricingService {}
class MockTransactionEngine extends Mock implements TransactionEngine {}

void main() {
  late MockAppDatabase mockDb;
  late MockPricingService mockPricing;
  late MockTransactionEngine mockTx;

  setUp(() {
    mockDb = MockAppDatabase();
    mockPricing = MockPricingService();
    mockTx = MockTransactionEngine();
  });

  setUpAll(() {
    // register a fallback Decimal for mocktail when using `any()` on Decimal
    registerFallbackValue(Decimal.zero);
  });

  test('PosBloc passes isWholesale flag to calculatePrice when refreshing',
      () async {
    // Arrange
    when(() => mockPricing.calculatePrice(
          productId: any(named: 'productId'),
          priceListId: any(named: 'priceListId'),
          quantity: any(named: 'quantity'),
          isWholesale: any(named: 'isWholesale'),
        )).thenAnswer((_) async => Decimal.parse('5'));

    // The DB is not used because skipInit=true
    final bloc = PosBloc(mockDb, mockPricing, mockTx, skipInit: true);

    // Create a dummy product to populate the cart
    final product = Product(
      id: 'p1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 1,
      name: 'Test',
      sku: 'SKU1',
      unit: 'حبة',
      cartonUnit: 'كرتون',
      piecesPerCarton: 1,
      buyPrice: 1.0,
      sellPrice: 10.0,
      wholesalePrice: 6.0,
      stock: 100.0,
      maxStock: 100.0,
      valuationMethod: 'FIFO',
      allowFreeQty: false,
      isService: false,
      alertLimit: 0.0,
      taxRate: 0.0,
      isActive: true,
    );

    // Inject a PosLoaded state with one cart item and wholesale mode enabled
    final cartItem = CartItem(
      product: product,
      quantity: Decimal.one,
      unitFactor: Decimal.one,
      unitPrice: Decimal.parse('10'),
      isWholesale: true,
    );

    // bypass access control to set state directly for test
    (bloc as dynamic).emit(PosLoaded(cart: [cartItem], isWholesaleMode: true));

    // Act: trigger price refresh
    bloc.add(RefreshPricesEvent());

    // give event loop a tick
    await Future.delayed(const Duration(milliseconds: 50));

    // Assert: verify calculatePrice was called with isWholesale = true
    verify(() => mockPricing.calculatePrice(
          productId: product.id,
          priceListId: null,
          quantity: cartItem.quantity,
          isWholesale: true,
        )).called(1);
  });
}
