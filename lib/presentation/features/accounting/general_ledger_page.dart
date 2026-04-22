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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.generalLedger), elevation: 0),
      body: StreamBuilder<List<GLEntry>>(
        stream: provider.watchEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return Center(child: Text(l10n.noTransactionsFound));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(entry.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(DateFormat('yyyy-MM-dd HH:mm').format(entry.date), style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                    ],
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.receipt_long, color: colorScheme.onPrimaryContainer, size: 20),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text(entry.referenceType ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer)),
                  ),
                  children: [
                    FutureBuilder<List<GLLineWithAccount>>(
                      future: provider.getEntryLines(entry.id),
                      builder: (context, lineSnapshot) {
                        if (!lineSnapshot.hasData) return const LinearProgressIndicator();
                        final lines = lineSnapshot.data!;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withAlpha(50), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                          child: Column(
                            children: lines.map((line) => _buildLineItem(context, line)).toList(),
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

  Widget _buildLineItem(BuildContext context, GLLineWithAccount line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.account.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(line.account.code, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          if (line.line.debit > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('مدين', style: TextStyle(fontSize: 9, color: Colors.green)),
                Text(line.line.debit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          if (line.line.credit > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('دائن', style: TextStyle(fontSize: 9, color: Colors.red)),
                Text(line.line.credit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
        ],
      ),
    );
  }
}
