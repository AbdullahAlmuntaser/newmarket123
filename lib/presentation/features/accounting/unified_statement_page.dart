import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/unified_statement_service.dart';
import 'package:supermarket/presentation/widgets/shared/account_selector_widget.dart';
import 'package:supermarket/presentation/widgets/shared/period_filter_widget.dart';
import 'package:intl/intl.dart' as intl;

class UnifiedStatementPage extends StatefulWidget {
  const UnifiedStatementPage({super.key});

  @override
  State<UnifiedStatementPage> createState() => _UnifiedStatementPageState();
}

class _UnifiedStatementPageState extends State<UnifiedStatementPage> {
  String? _accountId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<UnifiedStatementEntry>? _entries;
  bool _isLoading = false;

  Future<void> _loadStatement() async {
    if (_accountId == null) return;
    setState(() => _isLoading = true);
    final service = Provider.of<UnifiedStatementService>(context, listen: false);
    final result = await service.getUnifiedStatement(
      accountId: _accountId!,
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _entries = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف حساب موحد')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                AccountSelectorWidget(
                  selectedAccountId: _accountId,
                  onSelected: (acc) {
                    setState(() => _accountId = acc?.id);
                    _loadStatement();
                  },
                ),
                const SizedBox(height: 10),
                PeriodFilterWidget(
                  onFilter: (start, end) {
                    setState(() {
                      _startDate = start;
                      _endDate = end;
                    });
                    _loadStatement();
                  },
                ),
              ],
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_entries != null)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('البيان')),
                      DataColumn(label: Text('مدين')),
                      DataColumn(label: Text('دائن')),
                      DataColumn(label: Text('الرصيد')),
                    ],
                    rows: _entries!.map((e) {
                      return DataRow(cells: [
                        DataCell(Text(intl.DateFormat('yyyy-MM-dd').format(e.date))),
                        DataCell(Text(e.description)),
                        DataCell(Text(e.debit.toStringAsFixed(2))),
                        DataCell(Text(e.credit.toStringAsFixed(2))),
                        DataCell(Text(e.balance.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
