import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class CashFlowPage extends StatefulWidget {
  const CashFlowPage({super.key});

  @override
  State<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends State<CashFlowPage> {
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedRange) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cashFlow),
        actions: [
          TextButton.icon(
            onPressed: () => _selectDateRange(context),
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: Text(
              '${DateFormat.yMMMd().format(_selectedRange.start)} - ${DateFormat.yMMMd().format(_selectedRange.end)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<CashFlowData>(
        future: provider.getCashFlow(
          startDate: _selectedRange.start,
          endDate: _selectedRange.end,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final currency = NumberFormat.currency(symbol: '');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            l10n.cashFlow,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${DateFormat.yMMMd().format(_selectedRange.start)} - ${DateFormat.yMMMd().format(_selectedRange.end)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(context, l10n.operatingActivities),
                    _buildRow(
                      l10n.netCashFromOperating,
                      data.operatingActivities,
                      currency,
                    ),
                    const Divider(),
                    _buildSectionHeader(context, l10n.investingActivities),
                    _buildRow(
                      l10n.netCashFromInvesting,
                      data.investingActivities,
                      currency,
                    ),
                    const Divider(),
                    _buildSectionHeader(context, l10n.financingActivities),
                    _buildRow(
                      l10n.netCashFromFinancing,
                      data.financingActivities,
                      currency,
                    ),
                    const Divider(thickness: 2),
                    _buildRow(
                      l10n.netChangeInCash,
                      data.netCashFlow,
                      currency,
                      isBold: true,
                    ),
                    const SizedBox(height: 32),
                    _buildRow(
                      l10n.beginningCashBalance,
                      data.beginningCashBalance,
                      currency,
                    ),
                    _buildRow(
                      l10n.endingCashBalance,
                      data.endingCashBalance,
                      currency,
                      isBold: true,
                      hasUnderline: true,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    double amount,
    NumberFormat currency, {
    bool isBold = false,
    bool hasUnderline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Container(
            decoration: hasUnderline
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(width: 2, style: BorderStyle.solid),
                    ),
                  )
                : null,
            child: Text(
              currency.format(amount),
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: amount < 0
                    ? Colors.red
                    : (amount > 0 ? Colors.green : Colors.black),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
