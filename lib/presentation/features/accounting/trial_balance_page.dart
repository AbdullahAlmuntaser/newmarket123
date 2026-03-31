import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class TrialBalancePage extends StatelessWidget {
  const TrialBalancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      body: FutureBuilder<List<TrialBalanceItem>>(
        future: provider.getTrialBalance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];

          double totalDebit = 0;
          double totalCredit = 0;
          for (var item in items) {
            totalDebit += item.totalDebit;
            totalCredit += item.totalCredit;
          }

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                DataTable(
                  columns: [
                    DataColumn(label: Text(l10n.accountName)),
                    DataColumn(label: Text(l10n.debit), numeric: true),
                    DataColumn(label: Text(l10n.credit), numeric: true),
                  ],
                  rows: [
                    ...items.map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.account.name)),
                          DataCell(
                            Text(
                              item.totalDebit > 0
                                  ? item.totalDebit.toStringAsFixed(2)
                                  : '-',
                            ),
                          ),
                          DataCell(
                            Text(
                              item.totalCredit > 0
                                  ? item.totalCredit.toStringAsFixed(2)
                                  : '-',
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataRow(
                      selected: true,
                      cells: [
                        DataCell(
                          Text(
                            l10n.total,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          Text(
                            totalDebit.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          Text(
                            totalCredit.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
