import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PurchaseReturnPage extends StatelessWidget {
  const PurchaseReturnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseReturns)),
      body: StreamBuilder<List<PurchaseReturn>>(
        stream: db.purchasesDao.watchAllPurchaseReturns(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final returns = snapshot.data ?? [];
          if (returns.isEmpty) {
            return Center(child: Text(l10n.noReturnsYet));
          }
          return ListView.builder(
            itemCount: returns.length,
            itemBuilder: (context, index) {
              final ret = returns[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(l10n.returnIdLabel(ret.id.substring(0, 8))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.amountReturnedLabel(
                          ret.amountReturned.toStringAsFixed(2),
                        ),
                      ),
                      Text(
                        l10n.dateLabel(
                          DateFormat('yyyy-MM-dd HH:mm').format(ret.createdAt),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Could show details here if needed
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/purchases/returns/new');
        },
        tooltip: l10n.newPurchaseReturn,
        child: const Icon(Icons.add),
      ),
    );
  }
}
