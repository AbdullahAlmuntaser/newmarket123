import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, OrderBy;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/export_service.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:intl/intl.dart';

class AdvancedProfitReportPage extends StatefulWidget {
  const AdvancedProfitReportPage({super.key});

  @override
  State<AdvancedProfitReportPage> createState() =>
      _AdvancedProfitReportPageState();
}

class _AdvancedProfitReportPageState extends State<AdvancedProfitReportPage> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _profitByCategory = [];
  double _totalRevenue = 0;
  double _totalCOGS = 0;
  double _totalProfit = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = di.sl<AppDatabase>();

    final revenueExpr = CustomExpression<double>(
        'SUM(${db.saleItems.quantity.name} * ${db.saleItems.price.name})');
    final cogsExpr = CustomExpression<double>(
        'SUM(${db.saleItems.quantity.name} * ${db.products.buyPrice.name})');

    final query = db.selectOnly(db.saleItems).join([
      innerJoin(db.sales, db.sales.id.equalsExp(db.saleItems.saleId)),
      innerJoin(db.products, db.products.id.equalsExp(db.saleItems.productId)),
      leftOuterJoin(
          db.categories, db.categories.id.equalsExp(db.products.categoryId)),
    ])
      ..where(db.sales.createdAt.isBiggerOrEqual(Variable(_startDate)) &
          db.sales.createdAt.isSmallerOrEqual(Variable(_endDate)))
      ..addColumns([
        db.categories.name,
        revenueExpr,
        cogsExpr,
      ])
      ..groupBy([db.categories.name]);

    final rows = await query.get();
    _profitByCategory = rows.map((row) {
      final revenue = (row.read(revenueExpr) ?? 0).toDouble();
      final cogs = (row.read(cogsExpr) ?? 0).toDouble();
      return {
        'category': row.read(db.categories.name) ?? 'غير محدد',
        'revenue': revenue,
        'cogs': cogs,
        'profit': revenue - cogs,
        'margin': revenue > 0 ? ((revenue - cogs) / revenue * 100) : 0.0,
      };
    }).toList();

    _profitByCategory.sort(
        (a, b) => (b['profit'] as double).compareTo(a['profit'] as double));
    _totalRevenue = _profitByCategory.fold<double>(
        0, (sum, e) => sum + (e['revenue'] as double));
    _totalCOGS = _profitByCategory.fold<double>(
        0, (sum, e) => sum + (e['cogs'] as double));
    _totalProfit = _totalRevenue - _totalCOGS;

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الأرباح المتقدم'),
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf), onPressed: _export),
          IconButton(icon: const Icon(Icons.table_chart), onPressed: _export),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDateFilter(),
                _buildSummaryCard(),
                const SizedBox(height: 16),
                const Text('الأرباح حسب التصنيف',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._profitByCategory.map((e) => _buildCategoryCard(e)),
              ],
            ),
    );
  }

  Widget _buildDateFilter() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now());
              if (date != null) {
                setState(() {
                  _startDate = date;
                  _loadData();
                });
              }
            },
            child: Text('من: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now());
              if (date != null) {
                setState(() {
                  _endDate = date;
                  _loadData();
                });
              }
            },
            child: Text('إلى: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('الإيرادات', _totalRevenue, Colors.green),
                _summaryItem('تكلفة البضاعة', _totalCOGS, Colors.orange),
                _summaryItem('صافي الربح', _totalProfit,
                    _totalProfit >= 0 ? Colors.blue : Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            if (_totalRevenue > 0)
              LinearProgressIndicator(
                value: (_totalProfit / _totalRevenue).clamp(0, 1),
                backgroundColor: Colors.red[100],
                valueColor: AlwaysStoppedAnimation(
                    _totalProfit >= 0 ? Colors.green : Colors.red),
              ),
            if (_totalRevenue > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'نسبة الربح: ${(_totalProfit / _totalRevenue * 100).toStringAsFixed(1)}%'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text('${value.toStringAsFixed(2)} ر.س',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> item) {
    final margin = item['margin'] as double;
    return Card(
      child: ListTile(
        title: Text(item['category']),
        subtitle: Row(
          children: [
            Text('إيراد: ${(item['revenue'] as double).toStringAsFixed(0)}'),
            const SizedBox(width: 12),
            Text('ربح: ${(item['profit'] as double).toStringAsFixed(0)}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: margin >= 20
                ? Colors.green[100]
                : margin >= 10
                    ? Colors.orange[100]
                    : Colors.red[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('${margin.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: margin >= 20
                      ? Colors.green
                      : margin >= 10
                          ? Colors.orange
                          : Colors.red,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _export() async {
    final service = ExportService(di.sl<AppDatabase>());
    await service.exportToCsv(
        'advanced_profit',
        _profitByCategory
            .map((e) => {
                  'category': e['category'],
                  'revenue': (e['revenue'] as double).toString(),
                  'cogs': (e['cogs'] as double).toString(),
                  'profit': (e['profit'] as double).toString(),
                  'margin': '${(e['margin'] as double).toStringAsFixed(1)}%',
                })
            .toList());
  }
}
