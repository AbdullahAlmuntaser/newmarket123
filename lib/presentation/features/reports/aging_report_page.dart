import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class AgingReportPage extends StatefulWidget {
  const AgingReportPage({super.key});

  @override
  State<AgingReportPage> createState() => _AgingReportPageState();
}

class _AgingReportPageState extends State<AgingReportPage> {
  String _type = 'CUSTOMER'; // CUSTOMER or SUPPLIER

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.agingReport)),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'CUSTOMER', child: Text('العملاء')),
                DropdownMenuItem(value: 'SUPPLIER', child: Text('الموردين')),
              ],
              onChanged: (v) => setState(() => _type = v!),
              decoration: InputDecoration(labelText: l10n.selectType),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AgingData>>(
              future: _fetchAging(db),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text(l10n.current)),
                      DataColumn(label: Text(l10n.days30)),
                      DataColumn(label: Text(l10n.days60)),
                      DataColumn(label: Text(l10n.days90Plus)),
                      DataColumn(label: Text(l10n.totalDue)),
                    ],
                    rows: data.map((d) => DataRow(cells: [
                      DataCell(Text(d.name)),
                      DataCell(Text(NumberFormat.currency(symbol: '').format(d.current))),
                      DataCell(Text(NumberFormat.currency(symbol: '').format(d.days30))),
                      DataCell(Text(NumberFormat.currency(symbol: '').format(d.days60))),
                      DataCell(Text(NumberFormat.currency(symbol: '').format(d.days90Plus))),
                      DataCell(Text(NumberFormat.currency(symbol: '').format(d.total))),
                    ])).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<AgingData>> _fetchAging(AppDatabase db) async {
    final now = DateTime.now();
    final data = <AgingData>[];

    if (_type == 'CUSTOMER') {
      final customers = await db.select(db.customers).get();
      for (var c in customers) {
        final invs = await db.customersDao.getUnpaidARInvoices(c.id);
        double cur = 0, d30 = 0, d60 = 0, d90 = 0;
        for (var inv in invs) {
          final diff = now.difference(inv.dueDate ?? inv.invoiceDate).inDays;
          final amt = inv.totalAmount - inv.paidAmount;
          if (diff <= 0) {
            cur += amt;
          } else if (diff <= 30) {
            d30 += amt;
          } else if (diff <= 60) {
            d60 += amt;
          } else {
            d90 += amt;
          }
        }
        if (cur + d30 + d60 + d90 > 0) {
          data.add(AgingData(c.name, cur, d30, d60, d90));
        }
      }
    } else {
      final suppliers = await db.select(db.suppliers).get();
      for (var s in suppliers) {
        final invs = await db.suppliersDao.getUnpaidAPInvoices(s.id);
        double cur = 0, d30 = 0, d60 = 0, d90 = 0;
        for (var inv in invs) {
          final diff = now.difference(inv.dueDate ?? inv.invoiceDate).inDays;
          final amt = inv.totalAmount - inv.paidAmount;
          if (diff <= 0) {
            cur += amt;
          } else if (diff <= 30) {
            d30 += amt;
          } else if (diff <= 60) {
            d60 += amt;
          } else {
            d90 += amt;
          }
        }
        if (cur + d30 + d60 + d90 > 0) {
          data.add(AgingData(s.name, cur, d30, d60, d90));
        }
      }
    }
    return data;
  }
}

class AgingData {
  final String name;
  final double current;
  final double days30;
  final double days60;
  final double days90Plus;
  AgingData(this.name, this.current, this.days30, this.days60, this.days90Plus);
  double get total => current + days30 + days60 + days90Plus;
}
