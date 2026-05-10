import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/shared/period_filter_widget.dart';

class ExpensesByCenterPage extends StatefulWidget {
  const ExpensesByCenterPage({super.key});

  @override
  State<ExpensesByCenterPage> createState() => _ExpensesByCenterPageState();
}

class _ExpensesByCenterPageState extends State<ExpensesByCenterPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<dynamic>? _data;
  bool _isLoading = false;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final result = await db.accountingDao.getExpensesByCostCenter(
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _data = result;
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _loadData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات حسب مركز التكلفة')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PeriodFilterWidget(
              onFilter: (start, end) {
                setState(() {
                  _startDate = start;
                  _endDate = end;
                });
                _loadData();
              },
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_data != null)
            Expanded(
              child: ListView.builder(
                itemCount: _data!.length,
                itemBuilder: (context, index) {
                  final item = _data![index];
                  return ListTile(
                    title: Text(item.name),
                    trailing: Text(item.total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
