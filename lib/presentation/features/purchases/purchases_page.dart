import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchasesHistory)),
      drawer: const MainDrawer(),
      body: StreamBuilder<List<PurchasesWithSupplier>>(
        stream: _watchPurchasesWithSupplier(db),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final purchases = snapshot.data ?? [];
          if (purchases.isEmpty) {
            return Center(child: Text(l10n.noPurchasesFound));
          }
          return ListView.builder(
            itemCount: purchases.length,
            itemBuilder: (context, index) {
              final item = purchases[index];
              final purchase = item.purchase;
              final supplier = item.supplier;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(supplier?.name ?? l10n.walkInSupplier),
                  subtitle: Text(DateFormat.yMMMd().format(purchase.date)),
                  trailing: Text(
                    NumberFormat.currency(
                      symbol: l10n.currencySymbol,
                      decimalDigits: 2,
                    ).format(purchase.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => context.go('/purchases/${purchase.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/purchases/new'),
        label: Text(l10n.newPurchase),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Stream<List<PurchasesWithSupplier>> _watchPurchasesWithSupplier(
    AppDatabase db,
  ) {
    final query = db.select(db.purchases).join([
      drift.leftOuterJoin(
        db.suppliers,
        db.suppliers.id.equalsExp(db.purchases.supplierId),
      ),
    ])..orderBy([drift.OrderingTerm.desc(db.purchases.date)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return PurchasesWithSupplier(
          purchase: row.readTable(db.purchases),
          supplier: row.readTableOrNull(db.suppliers),
        );
      }).toList();
    });
  }
}

class PurchasesWithSupplier {
  final Purchase purchase;
  final Supplier? supplier;

  PurchasesWithSupplier({required this.purchase, this.supplier});
}
