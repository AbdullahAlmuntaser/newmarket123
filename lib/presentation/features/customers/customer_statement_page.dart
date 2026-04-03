import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supermarket/presentation/features/customers/customer_statement_provider.dart';

class CustomerStatementPage extends StatefulWidget {
  final String customerId;

  const CustomerStatementPage({super.key, required this.customerId});

  @override
  State<CustomerStatementPage> createState() => _CustomerStatementPageState();
}

class _CustomerStatementPageState extends State<CustomerStatementPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerStatementProvider>().loadStatement(widget.customerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب العميل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // مستقبلاً: إضافة طباعة كشف الحساب
            },
          ),
        ],
      ),
      body: Consumer<CustomerStatementProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.customer == null) {
            return const Center(child: Text('لم يتم العثور على العميل'));
          }

          return Column(
            children: [
              _buildSummaryHeader(context, provider),
              const Divider(height: 1),
              _buildTransactionsList(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, CustomerStatementProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Text(
            provider.customer!.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(context, 'إجمالي المبيعات', provider.totalDebit, Colors.red),
              _buildSummaryItem(context, 'إجمالي المدفوعات', provider.totalCredit, Colors.green),
              _buildSummaryItem(context, 'الرصيد المتبقي', provider.balance, Theme.of(context).colorScheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, double value, Color color) {
    final currency = intl.NumberFormat.currency(symbol: '');
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          currency.format(value),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(BuildContext context, CustomerStatementProvider provider) {
    if (provider.transactions.isEmpty) {
      return const Expanded(child: Center(child: Text('لا توجد حركات مالية لهذا العميل')));
    }

    double runningBalance = 0;

    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('البيان')),
              DataColumn(label: Text('عليه (مدين)')),
              DataColumn(label: Text('له (دائن)')),
              DataColumn(label: Text('الرصيد')),
            ],
            rows: provider.transactions.map((t) {
              runningBalance += (t.debit - t.credit);
              return DataRow(cells: [
                DataCell(Text(intl.DateFormat('yyyy/MM/dd').format(t.date))),
                DataCell(Text(t.description)),
                DataCell(Text(t.debit > 0 ? t.debit.toStringAsFixed(2) : '-')),
                DataCell(Text(t.credit > 0 ? t.credit.toStringAsFixed(2) : '-')),
                DataCell(Text(
                  runningBalance.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
