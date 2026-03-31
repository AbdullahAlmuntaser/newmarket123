import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class GeneralLedgerPage extends StatelessWidget {
  const GeneralLedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      body: StreamBuilder<List<GLEntry>>(
        stream: provider.watchEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('No entries found.'));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text(entry.description),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(entry.date),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.referenceType ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  children: [
                    FutureBuilder<List<GLLineWithAccount>>(
                      future: provider.getEntryLines(entry.id),
                      builder: (context, lineSnapshot) {
                        if (!lineSnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final lines = lineSnapshot.data!;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text(l10n.accountName)),
                              DataColumn(
                                label: Text(l10n.debit),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(l10n.credit),
                                numeric: true,
                              ),
                            ],
                            rows: lines.map((line) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '${line.account.code} - ${line.account.name}',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      line.line.debit > 0
                                          ? line.line.debit.toStringAsFixed(2)
                                          : '-',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      line.line.credit > 0
                                          ? line.line.credit.toStringAsFixed(2)
                                          : '-',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
