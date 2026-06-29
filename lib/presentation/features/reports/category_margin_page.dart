import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:fl_chart/fl_chart.dart';

class CategoryMarginPage extends StatefulWidget {
  const CategoryMarginPage({super.key});

  @override
  State<CategoryMarginPage> createState() => _CategoryMarginPageState();
}

class _CategoryMarginPageState extends State<CategoryMarginPage> {
  List<Map<String, dynamic>> _categoryData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = context.read<AppDatabase>();

    final categories = await (db.select(db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();

    final products = await db.select(db.products).get();
    final saleItems = await db.select(db.saleItems).get();

    final result = <Map<String, dynamic>>[];

    for (final category in categories) {
      final catProducts =
          products.where((p) => p.categoryId == category.id).toList();
      if (catProducts.isEmpty) continue;

      double totalRevenue = 0;
      double totalCost = 0;
      int totalQuantity = 0;

      for (final product in catProducts) {
        final productSales =
            saleItems.where((si) => si.productId == product.id);
        for (final sale in productSales) {
          final revenue = (sale.price * sale.quantity).toDouble();
          final cost = (product.buyPrice * sale.quantity).toDouble();
          totalRevenue += revenue;
          totalCost += cost;
          totalQuantity += int.parse(sale.quantity.toString());
        }
      }

      final margin = totalRevenue - totalCost;
      final marginPercent =
          totalRevenue > 0 ? (margin / totalRevenue) * 100 : 0.0;

      result.add({
        'name': category.name,
        'productCount': catProducts.length,
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'margin': margin,
        'marginPercent': marginPercent,
        'totalQuantity': totalQuantity,
      });
    }

    result.sort(
        (a, b) => (b['margin'] as double).compareTo(a['margin'] as double));

    setState(() {
      _categoryData = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير هامش الربح حسب التصنيف'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoryData.isEmpty
              ? const Center(child: Text('لا توجد بيانات'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildBarChart(),
                      const SizedBox(height: 16),
                      _buildDataTable(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBarChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هامش الربح حسب التصنيف',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _categoryData.isNotEmpty
                      ? _categoryData
                              .map((d) => d['margin'] as double)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2
                      : 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIdx, rod, rodIdx) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(0)} ر.س',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < _categoryData.length) {
                            final name = _categoryData[idx]['name'] as String;
                            return Text(
                              name.length > 8
                                  ? '${name.substring(0, 8)}..'
                                  : name,
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${(value / 1000).toStringAsFixed(0)}k',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _categoryData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final margin = data['margin'] as double;
                    final colors = [
                      Colors.blue,
                      Colors.green,
                      Colors.orange,
                      Colors.purple,
                      Colors.teal,
                      Colors.red
                    ];
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: margin,
                          color: colors[index % colors.length],
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('التصنيف')),
            DataColumn(label: Text('المنتجات')),
            DataColumn(label: Text('الإيراد')),
            DataColumn(label: Text('التكلفة')),
            DataColumn(label: Text('الهامش')),
            DataColumn(label: Text('نسبة الهامش %')),
          ],
          rows: _categoryData.map((d) {
            final marginPercent = d['marginPercent'] as double;
            final color = marginPercent > 30
                ? Colors.green
                : marginPercent > 15
                    ? Colors.orange
                    : Colors.red;

            return DataRow(cells: [
              DataCell(Text(d['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text('${d['productCount']}')),
              DataCell(Text((d['totalRevenue'] as double).toStringAsFixed(0))),
              DataCell(Text((d['totalCost'] as double).toStringAsFixed(0))),
              DataCell(Text(
                (d['margin'] as double).toStringAsFixed(0),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              )),
              DataCell(Text(
                '${marginPercent.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
