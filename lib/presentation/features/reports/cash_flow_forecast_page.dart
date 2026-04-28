import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class CashFlowForecastPage extends StatefulWidget {
  const CashFlowForecastPage({super.key});

  @override
  State<CashFlowForecastPage> createState() => _CashFlowForecastPageState();
}

class _CashFlowForecastPageState extends State<CashFlowForecastPage> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cashFlowForecast)),
      drawer: const MainDrawer(),
      body: FutureBuilder<List<ForecastData>>(
        future: _fetchForecast(db),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DataTable(
                columns: [
                  DataColumn(label: Text(l10n.period)),
                  DataColumn(label: Text(l10n.inflow)),
                  DataColumn(label: Text(l10n.outflow)),
                  DataColumn(label: Text(l10n.netCash)),
                ],
                rows: data.map((d) => DataRow(cells: [
                  DataCell(Text(d.period)),
                  DataCell(Text(NumberFormat.currency(symbol: '').format(d.inflow))),
                  DataCell(Text(NumberFormat.currency(symbol: '').format(d.outflow))),
                  DataCell(Text(NumberFormat.currency(symbol: '').format(d.inflow - d.outflow))),
                ])).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<ForecastData>> _fetchForecast(AppDatabase db) async {
    final now = DateTime.now();
    final periods = [
      (now, now.add(const Duration(days: 30)), '30 Days'),
      (now.add(const Duration(days: 31)), now.add(const Duration(days: 60)), '60 Days'),
      (now.add(const Duration(days: 61)), now.add(const Duration(days: 90)), '90 Days'),
    ];

    final data = <ForecastData>[];
    for (var p in periods) {
      final ar = await db.customersDao.getDueARInvoices(p.$2);
      final ap = await db.suppliersDao.getDueAPInvoices(p.$2);
      
      double inflow = ar.fold(0, (sum, i) => sum + (i.totalAmount - i.paidAmount));
      double outflow = ap.fold(0, (sum, i) => sum + (i.totalAmount - i.paidAmount));
      
      data.add(ForecastData(p.$3, inflow, outflow));
    }
    return data;
  }
}

class ForecastData {
  final String period;
  final double inflow;
  final double outflow;
  ForecastData(this.period, this.inflow, this.outflow);
}
