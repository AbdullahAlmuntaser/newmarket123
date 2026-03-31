import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart' as intl;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';

class VatReportPage extends StatefulWidget {
  const VatReportPage({super.key});

  @override
  State<VatReportPage> createState() => _VatReportPageState();
}

class _VatReportPageState extends State<VatReportPage> {
  DateTimeRange? _dateRange;
  Future<Map<String, double>>? _reportFuture;

  @override
  void initState() {
    super.initState();
    _dateRange = DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month, 1),
      end: DateTime.now(),
    );
    _generateReport();
  }

  void _generateReport() {
    final db = context.read<AccountingProvider>().db;
    setState(() {
      _reportFuture = _calculateVat(db, _dateRange!);
    });
  }

  Future<void> _selectDateRange() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDateRangePicker(
      context: context,
      helpText: l10n.selectDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _generateReport();
    }
  }

  Future<Map<String, double>> _calculateVat(
    AppDatabase db,
    DateTimeRange range,
  ) async {
    final dao = db.accountingDao;

    // 1. Output VAT (Tax on Sales - Code 2020)
    final outputVatAccount = await dao.getAccountByCode('2020');
    double totalSalesVat = 0.0;
    if (outputVatAccount != null) {
      totalSalesVat = await dao.getAccountBalanceInRange(
        outputVatAccount.id,
        range.start,
        range.end,
      );
    } else {
      // Fallback to simplified calculation if account doesn't exist yet
      final salesQuery = db.select(db.sales)
        ..where((t) => t.createdAt.isBetweenValues(range.start, range.end));
      final sales = await salesQuery.get();
      totalSalesVat = sales.fold<double>(0.0, (sum, sale) => sum + sale.tax);
    }

    // 2. Input VAT (Tax on Purchases - Code 1050)
    final inputVatAccount = await dao.getAccountByCode('1050');
    double totalPurchasesVat = 0.0;
    if (inputVatAccount != null) {
      totalPurchasesVat = await dao.getAccountBalanceInRange(
        inputVatAccount.id,
        range.start,
        range.end,
      );
    } else {
      // Fallback to simplified calculation if account doesn't exist yet
      final purchasesQuery = db.select(db.purchases)
        ..where((t) => t.date.isBetweenValues(range.start, range.end));
      final purchases = await purchasesQuery.get();
      totalPurchasesVat = purchases.fold<double>(
        0.0,
        (sum, p) => sum + (p.total - (p.total / 1.15)),
      );
    }

    return {
      'salesVat': totalSalesVat,
      'purchasesVat': totalPurchasesVat,
      'netVat': totalSalesVat - totalPurchasesVat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = intl.DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vatReturn),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: l10n.selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24.0),
            color: HSLColor.fromColor(Theme.of(context).primaryColor).withAlpha(0.05).toColor(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${dateFormat.format(_dateRange!.start)} - ${dateFormat.format(_dateRange!.end)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, double>>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return Center(child: Text(l10n.noDataAvailable));
                }

                final data = snapshot.data!;
                final salesVat = data['salesVat']!;
                final purchasesVat = data['purchasesVat']!;
                final netVat = data['netVat']!;

                return ListView(
                  padding: const EdgeInsets.all(20.0),
                  children: [
                    _buildReportCard(
                      title: l10n.vatOnSales,
                      amount: salesVat,
                      color: Colors.green,
                      icon: Icons.trending_up,
                    ),
                    const SizedBox(height: 12),
                    _buildReportCard(
                      title: l10n.vatOnPurchases,
                      amount: purchasesVat,
                      color: Colors.orange,
                      icon: Icons.trending_down,
                    ),
                    const Divider(height: 48, thickness: 2),
                    _buildReportCard(
                      title: l10n.netVatPayable,
                      amount: netVat,
                      color: netVat >= 0 ? Colors.blue : Colors.red,
                      isBold: true,
                      icon: Icons.account_balance,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    bool isBold = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: HSLColor.fromColor(color).withAlpha(0.1).toColor(),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
