import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/export_service.dart';
import 'package:supermarket/injection_container.dart' as di;

class IncomeExpenseReportPage extends StatefulWidget {
  const IncomeExpenseReportPage({super.key});

  @override
  State<IncomeExpenseReportPage> createState() =>
      _IncomeExpenseReportPageState();
}

class _IncomeExpenseReportPageState extends State<IncomeExpenseReportPage> {
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _netIncome = 0;
  List<Map<String, dynamic>> _expenseBreakdown = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = di.sl<AppDatabase>();

    final sales = await db.select(db.sales).get();
    _totalIncome = sales.fold<double>(0, (sum, s) => sum + s.total.toDouble());

    final glLines = await (db.select(db.gLLines).join([
      innerJoin(
          db.gLAccounts, db.gLAccounts.id.equalsExp(db.gLLines.accountId)),
    ])).get();

    _totalExpenses = 0;
    _expenseBreakdown = [];
    final expenseMap = <String, double>{};

    for (final row in glLines) {
      final account = row.readTable(db.gLAccounts);
      final line = row.readTable(db.gLLines);
      if (account.type == 'EXPENSE') {
        _totalExpenses += line.debit.toDouble();
        final name = account.name;
        expenseMap[name] = (expenseMap[name] ?? 0) + line.debit.toDouble();
      }
    }

    _expenseBreakdown = expenseMap.entries
        .map((e) => {'name': e.key, 'amount': e.value})
        .toList()
      ..sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    _netIncome = _totalIncome - _totalExpenses;

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الإيرادات والمصروفات'),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryItem(
                                'الإيرادات', _totalIncome, Colors.green),
                            _summaryItem(
                                'المصروفات', _totalExpenses, Colors.red),
                            _summaryItem('صافي الدخل', _netIncome,
                                _netIncome >= 0 ? Colors.blue : Colors.red),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _totalIncome > 0
                              ? (_netIncome / _totalIncome).clamp(0, 1)
                              : 0,
                          backgroundColor: Colors.red[100],
                          valueColor: AlwaysStoppedAnimation(
                              _netIncome >= 0 ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('تفصيل المصروفات',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._expenseBreakdown.map((e) => Card(
                      child: ListTile(
                        title: Text(e['name']),
                        trailing: Text(
                            '${(e['amount'] as double).toStringAsFixed(2)} ر.س',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )),
              ],
            ),
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text('${value.toStringAsFixed(2)} ر.س',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  void _export() async {
    final service = ExportService(di.sl<AppDatabase>());
    await service.exportToCsv('income_expense', [
      {'type': 'الإيرادات', 'amount': _totalIncome.toString()},
      {'type': 'المصروفات', 'amount': _totalExpenses.toString()},
      {'type': 'صافي الدخل', 'amount': _netIncome.toString()},
      ..._expenseBreakdown
          .map((e) => {'type': e['name'], 'amount': e['amount'].toString()}),
    ]);
  }
}
