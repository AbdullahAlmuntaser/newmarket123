import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:fl_chart/fl_chart.dart';

class AbcAnalysisPage extends StatefulWidget {
  const AbcAnalysisPage({super.key});

  @override
  State<AbcAnalysisPage> createState() => _AbcAnalysisPageState();
}

class _AbcAnalysisPageState extends State<AbcAnalysisPage> {
  List<Map<String, dynamic>> _abcData = [];
  bool _isLoading = true;
  String _filterClass = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = context.read<AppDatabase>();

    await db.select(db.sales).get();
    final saleItems = await db.select(db.saleItems).get();
    final products = await db.select(db.products).get();

    final productRevenue = <String, double>{};
    for (final item in saleItems) {
      final revenue = (item.price * item.quantity).toDouble();
      productRevenue[item.productId] =
          (productRevenue[item.productId] ?? 0) + revenue;
    }

    final totalRevenue =
        productRevenue.values.fold<double>(0, (sum, v) => sum + v);
    if (totalRevenue == 0) {
      setState(() {
        _abcData = [];
        _isLoading = false;
      });
      return;
    }

    final sortedProducts = productRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double cumulativePercent = 0;
    final abcList = <Map<String, dynamic>>[];

    for (final entry in sortedProducts) {
      final product = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => products.first,
      );
      cumulativePercent += (entry.value / totalRevenue) * 100;

      String abcClass;
      if (cumulativePercent <= 70) {
        abcClass = 'A';
      } else if (cumulativePercent <= 90) {
        abcClass = 'B';
      } else {
        abcClass = 'C';
      }

      abcList.add({
        'productId': entry.key,
        'name': product.name,
        'sku': product.sku,
        'revenue': entry.value,
        'percent': (entry.value / totalRevenue) * 100,
        'cumulativePercent': cumulativePercent,
        'class': abcClass,
      });
    }

    setState(() {
      _abcData = abcList;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_filterClass == 'ALL') return _abcData;
    return _abcData.where((d) => d['class'] == _filterClass).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحليل ABC للمنتجات'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ALL', label: Text('الكل')),
              ButtonSegment(value: 'A', label: Text('A')),
              ButtonSegment(value: 'B', label: Text('B')),
              ButtonSegment(value: 'C', label: Text('C')),
            ],
            selected: {_filterClass},
            onSelectionChanged: (val) =>
                setState(() => _filterClass = val.first),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _abcData.isEmpty
              ? const Center(child: Text('لا توجد بيانات مبيعات'))
              : Column(
                  children: [
                    _buildSummaryCards(),
                    _buildPieChart(),
                    Expanded(child: _buildDataTable()),
                  ],
                ),
    );
  }

  Widget _buildSummaryCards() {
    final countA = _abcData.where((d) => d['class'] == 'A').length;
    final countB = _abcData.where((d) => d['class'] == 'B').length;
    final countC = _abcData.where((d) => d['class'] == 'C').length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
              child:
                  _buildClassCard('A', countA, Colors.green, 'الأكثر أهمية')),
          const SizedBox(width: 8),
          Expanded(
              child:
                  _buildClassCard('B', countB, Colors.orange, 'متوسط الأهمية')),
          const SizedBox(width: 8),
          Expanded(
              child: _buildClassCard('C', countC, Colors.red, 'الأقل أهمية')),
        ],
      ),
    );
  }

  Widget _buildClassCard(
      String label, int count, Color color, String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text('$count منتج', style: const TextStyle(fontSize: 12)),
            Text(description,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final countA = _abcData.where((d) => d['class'] == 'A').length;
    final countB = _abcData.where((d) => d['class'] == 'B').length;
    final countC = _abcData.where((d) => d['class'] == 'C').length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('توزيع المنتجات حسب الفئة',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: countA.toDouble(),
                      title: 'A',
                      color: Colors.green,
                      radius: 50,
                    ),
                    PieChartSectionData(
                      value: countB.toDouble(),
                      title: 'B',
                      color: Colors.orange,
                      radius: 50,
                    ),
                    PieChartSectionData(
                      value: countC.toDouble(),
                      title: 'C',
                      color: Colors.red,
                      radius: 50,
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('الفئة')),
          DataColumn(label: Text('المنتج')),
          DataColumn(label: Text('الإيراد')),
          DataColumn(label: Text('النسبة %')),
          DataColumn(label: Text('التراكمي %')),
        ],
        rows: _filteredData.map((d) {
          final abcClass = d['class'] as String;
          final color = abcClass == 'A'
              ? Colors.green
              : abcClass == 'B'
                  ? Colors.orange
                  : Colors.red;

          return DataRow(cells: [
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(abcClass,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            )),
            DataCell(Text(d['name'])),
            DataCell(
                Text('${(d['revenue'] as double).toStringAsFixed(2)} ر.س')),
            DataCell(Text('${(d['percent'] as double).toStringAsFixed(1)}%')),
            DataCell(Text(
                '${(d['cumulativePercent'] as double).toStringAsFixed(1)}%')),
          ]);
        }).toList(),
      ),
    );
  }
}
