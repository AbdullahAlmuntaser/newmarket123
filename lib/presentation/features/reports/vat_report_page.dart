import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class VatReportPage extends StatefulWidget {
  const VatReportPage({super.key});

  @override
  State<VatReportPage> createState() => _VatReportPageState();
}

class _VatReportPageState extends State<VatReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate!.year, _endDate!.month, 1); // Default to start of current month
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
        title: Text(l10n.vatReport),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
            tooltip: l10n.selectDateRange,
          ),
        ],
      ),
      body: FutureBuilder<VatReportData>( // Assuming VatReportData will be created
        future: provider.getVatReport(startDate: _startDate, endDate: _endDate), // Assuming getVatReport will be added to AccountingProvider
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${l10n.errorLoadingData}: ${snapshot.error}'));
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
                _buildSummaryCard(l10n, data), // Will create this widget
                const SizedBox(height: 24),
                // Here we will list detailed transactions
                Text(l10n.vatOnSales, style: Theme.of(context).textTheme.titleMedium),
                // Example: ListView for sales with VAT
                // ...
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
            Text('${l10n.from}: ${formatter.format(_startDate ?? DateTime.now())}'),
            Text('${l10n.to}: ${formatter.format(_endDate ?? DateTime.now())}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n, VatReportData data) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.vatSummary, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow(l10n.totalOutputVat, data.totalOutputVat),
            _buildSummaryRow(l10n.totalInputVat, data.totalInputVat), // Assuming Input VAT from purchases later
            const Divider(),
            _buildSummaryRow(l10n.netVatPayable, data.netVatPayable, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(amount.toStringAsFixed(2), style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
        ],
      ),
    );
  }
}
