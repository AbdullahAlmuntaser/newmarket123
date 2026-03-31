import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/settings/providers/sync_provider.dart';

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final syncProvider = context.watch<SyncProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FutureBuilder<int>(
              future: db.getUnsyncedCount(),
              initialData: 0,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return ListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(l10n.syncStatus),
                  subtitle: Text(
                    count == 0
                        ? l10n.allChangesSynced
                        : l10n.unsyncedChanges(count.toString()),
                  ),
                  trailing: syncProvider.isSyncing
                      ? const CircularProgressIndicator()
                      : IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: count > 0
                              ? () => syncProvider.syncAll()
                              : null,
                          tooltip: l10n.syncNow,
                        ),
                );
              },
            ),
            if (syncProvider.lastSyncTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${l10n.lastSync}: ${syncProvider.lastSyncTime!.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
