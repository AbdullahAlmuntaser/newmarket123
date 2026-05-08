import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class MockDashboardData {
  final double totalSalesToday;
  final double inventoryValue;
  final int lowStockCount;
  final int creditLimitExceededCount;

  MockDashboardData({
    this.totalSalesToday = 1500.0,
    this.inventoryValue = 50000.0,
    this.lowStockCount = 5,
    this.creditLimitExceededCount = 2,
  });
}

class MockDashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  MockDashboardData? _data;

  bool get isLoading => _isLoading;
  MockDashboardData? get data => _data;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setData(MockDashboardData data) {
    _data = data;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    _data = MockDashboardData();
    _isLoading = false;
    notifyListeners();
  }
}

class SimpleDashboardView extends StatelessWidget {
  final MockDashboardProvider provider;

  const SimpleDashboardView({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => provider.refreshData(),
            ),
          ],
        ),
        body: Consumer<MockDashboardProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = provider.data;
            if (data == null) {
              return const Center(child: Text('لا توجد بيانات'));
            }

            return RefreshIndicator(
              onRefresh: provider.refreshData,
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                children: [
                  _buildStatCard(
                    'مبيعات اليوم',
                    data.totalSalesToday.toStringAsFixed(2),
                    Icons.shopping_cart,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'قيمة المخزون',
                    data.inventoryValue.toStringAsFixed(2),
                    Icons.inventory,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'تنبيهات المخزون',
                    '${data.lowStockCount}',
                    Icons.warning,
                    Colors.red,
                  ),
                  _buildStatCard(
                    'تجاوز ائتمان',
                    '${data.creditLimitExceededCount}',
                    Icons.account_balance_wallet,
                    Colors.purple,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('SimpleDashboardView Widget Tests', () {
    late MockDashboardProvider mockProvider;

    setUp(() {
      mockProvider = MockDashboardProvider();
    });

    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));

      expect(find.text('لوحة التحكم'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows loading indicator when loading', (tester) async {
      mockProvider.setLoading(true);

      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows no data message when data is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));

      expect(find.text('لا توجد بيانات'), findsOneWidget);
    });

    testWidgets('displays dashboard statistics when data available', (tester) async {
      mockProvider.setData(MockDashboardData());

      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));
      await tester.pumpAndSettle();

      expect(find.text('مبيعات اليوم'), findsOneWidget);
      expect(find.text('قيمة المخزون'), findsOneWidget);
      expect(find.text('تنبيهات المخزون'), findsOneWidget);
      expect(find.text('تجاوز ائتمان'), findsOneWidget);
    });

    testWidgets('displays correct values for stats', (tester) async {
      mockProvider.setData(MockDashboardData(
        totalSalesToday: 2500.50,
        inventoryValue: 75000.0,
        lowStockCount: 10,
        creditLimitExceededCount: 3,
      ));

      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2500.50'), findsOneWidget);
      expect(find.text('75000.00'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('displays stat cards with correct icons and colors', (tester) async {
      mockProvider.setData(MockDashboardData());

      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      expect(find.byIcon(Icons.inventory), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
    });

    testWidgets('has GridView for stats display', (tester) async {
      mockProvider.setData(MockDashboardData());

      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(4));
    });

    testWidgets('shows refresh indicator', (tester) async {
      mockProvider.setData(MockDashboardData());

      await tester.pumpWidget(MaterialApp(
        home: SimpleDashboardView(provider: mockProvider),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}