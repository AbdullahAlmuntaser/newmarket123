import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dashboard_provider.dart';
import 'package:supermarket/injection_container.dart';

class DashboardPage extends StatelessWidget {
  final String currentUserId;
  const DashboardPage({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DashboardProvider>().refreshData(),
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = provider.data;
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('خطأ: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: provider.refreshData,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          if (data == null) return const Center(child: Text('لا توجد بيانات'));

          return RefreshIndicator(
            onRefresh: provider.refreshData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildKPISection(context, data),
                const SizedBox(height: 16),
                _buildWeeklySalesChart(),
                const SizedBox(height: 16),
                if (data.topProducts.isNotEmpty) ...[
                  _buildTopProductsSection(data.topProducts),
                  const SizedBox(height: 16),
                ],
                if (data.categoryBreakdown.isNotEmpty) ...[
                  _buildCategoryBreakdownChart(data.categoryBreakdown),
                  const SizedBox(height: 16),
                ],
                _buildQuickActions(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKPISection(BuildContext context, DashboardData data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
            'مبيعات اليوم',
            '${data.totalSalesToday.toStringAsFixed(2)} ر.س',
            Icons.shopping_cart,
            Colors.green),
        _buildStatCard(
            'مشتريات اليوم',
            '${data.totalPurchasesToday.toStringAsFixed(2)} ر.س',
            Icons.shopping_bag,
            Colors.blue),
        _buildStatCard(
            'صافي الربح',
            '${data.netProfitToday.toStringAsFixed(2)} ر.س',
            Icons.attach_money,
            Colors.teal),
        _buildStatCard(
            'قيمة المخزون',
            '${data.inventoryValue.toStringAsFixed(2)} ر.س',
            Icons.inventory,
            Colors.orange),
        _buildStatCard(
            'العملاء', '${data.totalCustomers}', Icons.people, Colors.indigo),
        _buildStatCard(
            'الموردين', '${data.totalSuppliers}', Icons.business, Colors.brown),
        _buildStatCard(
            'الصناديق',
            '${data.cashboxBalance.toStringAsFixed(2)} ر.س',
            Icons.payments,
            Colors.purple,
            onTap: () => context.push('/accounting/cashbox')),
        _buildStatCard('طلبيات معلقة', '${data.pendingOrdersCount}',
            Icons.pending_actions, Colors.amber),
        _buildStatCard('تنبيهات المخزون', '${data.lowStockCount}',
            Icons.warning, Colors.red),
        _buildStatCard('تجاوز ائتمان', '${data.creditLimitExceededCount}',
            Icons.account_balance_wallet, Colors.pink),
      ],
    );
  }

  Widget _buildWeeklySalesChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مبيعات الأسبوع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<FlSpot>>(
                future: _getWeeklySalesData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final spots = snapshot.data ?? [];
                  if (spots.isEmpty) {
                    return const Center(child: Text('لا توجد بيانات'));
                  }
                  return LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: true, reservedSize: 40)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final days = [
                                'سبت',
                                'أحد',
                                'اثنين',
                                'ثلاثاء',
                                'أربعاء',
                                'خميس',
                                'جمعة'
                              ];
                              final index = value.toInt();
                              if (index >= 0 && index < 7) {
                                return Text(days[index],
                                    style: const TextStyle(fontSize: 10));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.withAlpha(25),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<FlSpot>> _getWeeklySalesData() async {
    final db = sl<AppDatabase>();
    final now = DateTime.now();
    final spots = <FlSpot>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final sales = await (db.select(db.sales)
            ..where((s) =>
                s.createdAt.isBiggerOrEqual(Variable(startOfDay)) &
                s.createdAt.isSmallerOrEqual(Variable(endOfDay))))
          .get();

      final total = sales.fold<double>(0, (sum, s) => sum + s.total.toDouble());
      spots.add(FlSpot((6 - i).toDouble(), total));
    }

    return spots;
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إجراءات سريعة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton(
                    context, 'نقطة البيع', Icons.point_of_sale, '/pos'),
                _actionButton(
                    context, 'المبيعات', Icons.receipt_long, '/sales'),
                _actionButton(
                    context, 'المنتجات', Icons.inventory_2, '/products'),
                _actionButton(context, 'التقارير', Icons.analytics, '/reports'),
                _actionButton(context, 'العملاء', Icons.people, '/customers'),
                _actionButton(context, 'المخزون', Icons.warehouse,
                    '/inventory/warehouses'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
      BuildContext context, String label, IconData icon, String route) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => context.push(route),
    );
  }

  Widget _buildTopProductsSection(List<Map<String, dynamic>> topProducts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الأكثر مبيعاً اليوم',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  child: Text('${index + 1}',
                      style: const TextStyle(fontSize: 12)),
                ),
                title: Text(product['name'] as String,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    'الكمية: ${(product['quantity'] as double).toStringAsFixed(0)}'),
                trailing: Text(
                  '${(product['revenue'] as double).toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownChart(
      List<Map<String, dynamic>> categoryBreakdown) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تصنيفات المنتجات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: categoryBreakdown.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    final value = cat['value'] as double;
                    return PieChartSectionData(
                      value: value > 0 ? value : 1,
                      title: cat['name'] as String,
                      color: colors[index % colors.length],
                      radius: 80,
                      titleStyle: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: categoryBreakdown.asMap().entries.map((entry) {
                final index = entry.key;
                final cat = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 12,
                        height: 12,
                        color: colors[index % colors.length]),
                    const SizedBox(width: 4),
                    Text('${cat['name']} (${cat['count']})',
                        style: const TextStyle(fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(title,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
