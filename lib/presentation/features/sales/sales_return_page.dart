import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class SalesReturnPage extends StatelessWidget {
  const SalesReturnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesReturns)),
      body: FutureBuilder<List<SalesReturn>>(
        future: (db.select(db.salesReturns)
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final returns = snapshot.data!;
          if (returns.isEmpty) {
            return Center(child: Text(l10n.noReturnsYet));
          }
          return ListView.builder(
            itemCount: returns.length,
            itemBuilder: (context, index) {
              final ret = returns[index];
              return ListTile(
                title: Text('مرتجع رقم: ${ret.id.substring(0, 8)}'),
                subtitle:
                    Text('المبلغ: ${ret.amountReturned.toStringAsFixed(2)}'),
                trailing: Text(ret.createdAt.toString().split(' ')[0]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/sales/returns/new');
        },
        tooltip: l10n.newSalesReturn,
        child: const Icon(Icons.add),
      ),
    );
  }
}
