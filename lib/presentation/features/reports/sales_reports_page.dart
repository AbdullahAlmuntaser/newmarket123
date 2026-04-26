import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class SalesReportsPage extends StatefulWidget {
  const SalesReportsPage({super.key});

  @override
  State<SalesReportsPage> createState() => _SalesReportsPageState();
}

class _SalesReportsPageState extends State<SalesReportsPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _selectedSaleType = 'all'; // all, retail, wholesale

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.viewReports),
        actions: [
          DropdownButton<String>(
            value: _selectedSaleType,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('الكل')),
              DropdownMenuItem(value: 'retail', child: Text('تجزئة')),
              DropdownMenuItem(value: 'wholesale', child: Text('جملة')),
            ],
            onChanged: (value) => setState(() => _selectedSaleType = value!),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(db, l10n),
            const SizedBox(height: 24),
            Text(l10n.revenue, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildSalesChart(db),
            const SizedBox(height: 24),
            Text(
              'المنتجات الأكثر مبيعاً',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildTopProductsList(db),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Widget _buildSummaryCards(AppDatabase db, AppLocalizations l10n) {
    return FutureBuilder<List<Sale>>(
      future:
          (db.select(db.sales)..where((t) {
                final dateFilter = t.createdAt.isBetween(
                  Variable(_startDate),
                  Variable(_endDate),
                );
                if (_selectedSaleType == 'all') return dateFilter;
                return dateFilter & t.saleType.equals(_selectedSaleType);
              }))
              .get(),
      builder: (context, snapshot) {
        final sales = snapshot.data ?? [];
        final totalRevenue = sales.fold(0.0, (sum, sale) => sum + sale.total);

        final retailSales = sales.where((s) => s.saleType == 'retail');
        final wholesaleSales = sales.where((s) => s.saleType == 'wholesale');

        final retailTotal = retailSales.fold(0.0, (sum, s) => sum + s.total);
        final wholesaleTotal = wholesaleSales.fold(
          0.0,
          (sum, s) => sum + s.total,
        );

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    l10n.totalSales,
                    totalRevenue.toStringAsFixed(2),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryCard(
                    'عدد العمليات',
                    sales.length.toString(),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedSaleType == 'all')
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'مبيعات التجزئة',
                      retailTotal.toStringAsFixed(2),
                      Icons.person,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      'مبيعات الجملة',
                      wholesaleTotal.toStringAsFixed(2),
                      Icons.business,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(AppDatabase db) {
    return SizedBox(
      height: 250,
      child: FutureBuilder<List<Sale>>(
        future:
            (db.select(db.sales)..where(
                  (t) => t.createdAt.isBetween(
                    Variable(_startDate),
                    Variable(_endDate),
                  ),
                ))
                .get(),
        builder: (context, snapshot) {
          final sales = snapshot.data ?? [];

          // Group sales by day
          Map<int, double> dailyTotals = {};
          for (var sale in sales) {
            final day = sale.createdAt.difference(_startDate).inDays;
            dailyTotals[day] = (dailyTotals[day] ?? 0) + sale.total;
          }

          List<FlSpot> spots = dailyTotals.entries
              .map((e) => FlSpot(e.key.toDouble(), e.value))
              .toList();
          spots.sort((a, b) => a.x.compareTo(b.x));

          if (spots.isEmpty) {
            return const Center(child: Text('لا توجد بيانات للعرض'));
          }

          return LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: const FlTitlesData(show: true),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).primaryColor,
                  barWidth: 4,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopProductsList(AppDatabase db) {
    return FutureBuilder<List<DashboardTopProduct>>(
      future: db.salesDao
          .getTopSellingProducts(limit: 5)
          .then(
            (list) => list
                .map(
                  (p) => DashboardTopProduct(p.product.name, p.totalQuantity),
                )
                .toList(),
          ),
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            return ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(p.productName),
              trailing: Text('${p.quantity.toStringAsFixed(0)} وحدة'),
            );
          },
        );
      },
    );
  }
}

class DashboardTopProduct {
  final String productName;
  final double quantity;
  DashboardTopProduct(this.productName, this.quantity);
}
