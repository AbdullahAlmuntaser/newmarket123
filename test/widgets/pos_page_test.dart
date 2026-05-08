import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockProduct {
  final String id;
  final String name;
  final double price;
  final double stock;

  MockProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });
}

class MockCartItem {
  final MockProduct product;
  int quantity;

  MockCartItem({required this.product, this.quantity = 1});
}

class SimplePosView extends StatelessWidget {
  final List<MockProduct> products;
  final List<MockCartItem> cart;
  final Function(MockProduct) onAddToCart;

  const SimplePosView({
    super.key,
    required this.products,
    required this.cart,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${cart.length}'),
              isLabelVisible: cart.isNotEmpty,
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'البحث عن منتج...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: InkWell(
                    onTap: () => onAddToCart(product),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2, size: 40, color: Colors.teal),
                        const SizedBox(height: 8),
                        Text(product.name, textAlign: TextAlign.center),
                        Text('${product.price.toStringAsFixed(2)} ر.س',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('المخزون: ${product.stock.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.payment),
        label: const Text('الدفع'),
      ),
    );
  }
}

void main() {
  group('SimplePosView Widget Tests', () {
    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SimplePosView(
          products: const [],
          cart: const [],
          onAddToCart: (_) {},
        ),
      ));

      expect(find.text('نقطة البيع'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
    });

    testWidgets('displays search field', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SimplePosView(
          products: const [],
          cart: const [],
          onAddToCart: (_) {},
        ),
      ));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('البحث عن منتج...'), findsOneWidget);
    });

    testWidgets('displays product grid with products', (tester) async {
      final products = [
        MockProduct(id: '1', name: 'ماء', price: 2.5, stock: 100),
        MockProduct(id: '2', name: 'خبز', price: 1.5, stock: 50),
        MockProduct(id: '3', name: 'حليب', price: 4.0, stock: 30),
      ];

      await tester.pumpWidget(MaterialApp(
        home: SimplePosView(
          products: products,
          cart: const [],
          onAddToCart: (_) {},
        ),
      ));

      expect(find.text('ماء'), findsOneWidget);
      expect(find.text('خبز'), findsOneWidget);
      expect(find.text('حليب'), findsOneWidget);
      expect(find.text('2.50 ر.س'), findsOneWidget);
    });

    testWidgets('shows cart badge with item count', (tester) async {
      final products = [
        MockProduct(id: '1', name: 'ماء', price: 2.5, stock: 100),
      ];

      await tester.pumpWidget(MaterialApp(
        home: SimplePosView(
          products: products,
          cart: [
            MockCartItem(product: products[0], quantity: 3),
          ],
          onAddToCart: (_) {},
        ),
      ));

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('has floating payment button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SimplePosView(
          products: const [],
          cart: const [],
          onAddToCart: (_) {},
        ),
      ));

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('الدفع'), findsOneWidget);
    });

    testWidgets('displays product cards with icons', (tester) async {
      final products = [
        MockProduct(id: '1', name: 'منتج 1', price: 10.0, stock: 20),
      ];

      await tester.pumpWidget(MaterialApp(
        home: SimplePosView(
          products: products,
          cart: const [],
          onAddToCart: (_) {},
        ),
      ));

      expect(find.byIcon(Icons.inventory_2), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });
  });
}