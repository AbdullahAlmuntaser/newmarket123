import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class IncomeStatementPage extends StatefulWidget {
  const IncomeStatementPage({super.key});

  @override
  State<IncomeStatementPage> createState() => _IncomeStatementPageState();
}

class _IncomeStatementPageState extends State<IncomeStatementPage> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(
      _endDate!.year,
      _endDate!.month,
      1,
    ); // Default to start of current month
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now(),
      end: _endDate ?? DateTime.now(),
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: initialDateRange,
    );

    if (picked != null && picked != initialDateRange) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.incomeStatement),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
            tooltip: l10n.selectDateRange,
          ),
        ],
      ),
      body: FutureBuilder<IncomeStatementData>(
        future: provider.getIncomeStatement(
          startDate: _startDate,
          endDate: _endDate,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('${l10n.errorLoadingData}: ${snapshot.error}'),
            );
          }
          final data = snapshot.data;
          if (data == null) return Center(child: Text(l10n.noDataAvailable));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateRangeDisplay(l10n),
                const SizedBox(height: 16),
                _buildSectionHeader(l10n.revenue),
                ...data.revenues.map(
                  (item) =>
                      _buildAccountRow(item.account.name, item.totalCredit),
                ),
                const Divider(thickness: 2),
                _buildTotalRow(l10n.totalRevenue, data.totalRevenue),
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.expenses),
                ...data.expenses.map(
                  (item) =>
                      _buildAccountRow(item.account.name, item.totalDebit),
                ),
                const Divider(thickness: 2),
                _buildTotalRow(l10n.totalExpense, data.totalExpense),
                const SizedBox(height: 32),
                _buildNetIncomeRow(l10n.netIncome, data.netIncome),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeDisplay(AppLocalizations l10n) {
    final formatter = DateFormat('dd-MM-yyyy');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${l10n.from}: ${formatter.format(_startDate ?? DateTime.now())}',
            ),
            Text('${l10n.to}: ${formatter.format(_endDate ?? DateTime.now())}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAccountRow(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(name), Text(amount.toStringAsFixed(2))],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          amount.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildNetIncomeRow(String label, double amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: amount >= 0
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        border: Border.all(color: amount >= 0 ? Colors.green : Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: amount >= 0 ? Colors.green : Colors.red,
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: amount >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
