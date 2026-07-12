import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/core/services/pricing_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockPricingService extends Mock implements PricingService {}

class MockTransactionEngine extends Mock implements TransactionEngine {}

class MockPackagingEngine extends Mock implements PackagingEngine {}

void main() {
  late MockAppDatabase mockDb;
  late MockPricingService mockPricing;
  late MockTransactionEngine mockTx;
  late MockPackagingEngine mockPkg;

  setUp(() {
    mockDb = MockAppDatabase();
    mockPricing = MockPricingService();
    mockTx = MockTransactionEngine();
    mockPkg = MockPackagingEngine();
  });

  setUpAll(() {
    registerFallbackValue(Decimal.zero);
  });

  test('PosBloc passes isWholesale flag to calculatePrice when refreshing',
      () async {
    when(() => mockPricing.calculatePrice(
          productId: any(named: 'productId'),
          priceListId: any(named: 'priceListId'),
          quantity: any(named: 'quantity'),
          isWholesale: any(named: 'isWholesale'),
        )).thenAnswer((_) async => Decimal.parse('5'));

    final bloc = PosBloc(mockDb, mockPricing, mockTx, mockPkg, skipInit: true);

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
      buyPrice: Decimal.parse('1.0'),
      sellPrice: Decimal.parse('10.0'),
      wholesalePrice: Decimal.parse('6.0'),
      stock: Decimal.parse('100.0'),
      maxStock: Decimal.parse('100.0'),
      valuationMethod: 'FIFO',
      allowFreeQty: false,
      isService: false,
      alertLimit: Decimal.zero,
      taxRate: Decimal.zero,
      isActive: true,
    );

    final cartItem = CartItem(
      product: product,
      quantity: Decimal.one,
      unitFactor: Decimal.one,
      unitPrice: Decimal.parse('10'),
      isWholesale: true,
    );

    (bloc as dynamic).emit(PosLoaded(cart: [cartItem], isWholesaleMode: true));

    bloc.add(RefreshPricesEvent());

    await Future.delayed(const Duration(milliseconds: 50));

    verify(() => mockPricing.calculatePrice(
          productId: product.id,
          priceListId: null,
          quantity: cartItem.quantity,
          isWholesale: true,
        )).called(1);
  });
}
