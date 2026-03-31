import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.auditLog)),
      body: StreamBuilder<List<AuditLog>>(
        stream:
            (provider.db.select(provider.db.auditLogs)..orderBy([
                  (t) => drift.OrderingTerm(
                    expression: t.timestamp,
                    mode: drift.OrderingMode.desc,
                  ),
                ]))
                .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(l10n.noSalesFound),
            ); // Use a generic "no data" message
          }

          final logs = snapshot.data!;

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    _getActionIcon(log.action),
                    color: _getActionColor(log.action),
                  ),
                  title: Text('${log.action}: ${log.targetEntity}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.details ?? ''),
                      Text(
                        intl.DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(log.timestamp),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Text(log.userId ?? 'System'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Icons.add_circle;
      case 'UPDATE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
