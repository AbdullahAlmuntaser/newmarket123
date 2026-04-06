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
      body: StreamBuilder<List<PurchasesWithSupplierAndWarehouse>>(
        stream: _watchPurchasesDetailed(db),
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
              final warehouse = item.warehouse;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(supplier?.name ?? l10n.walkInSupplier),
                      _buildStatusChip(context, purchase.status, l10n),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat.yMMMd().format(purchase.date)),
                      if (warehouse != null)
                        Text('${l10n.warehouse}: ${warehouse.name}'),
                    ],
                  ),
                  trailing: Text(
                    NumberFormat.currency(
                      symbol: l10n.currencySymbol,
                      decimalDigits: 2,
                    ).format(purchase.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

  Widget _buildStatusChip(
    BuildContext context,
    String status,
    AppLocalizations l10n,
  ) {
    Color chipColor;
    Color textColor = Colors.white;
    String label;
    switch (status) {
      case 'DRAFT':
        chipColor = Theme.of(context).colorScheme.onSurfaceVariant;
        textColor = Theme.of(context).colorScheme.onPrimary;
        label = l10n.draft;
        break;
      case 'ORDERED':
        chipColor = Theme.of(context).colorScheme.primary;
        textColor = Theme.of(context).colorScheme.onPrimary;
        label = l10n.ordered;
        break;
      case 'RECEIVED':
        chipColor = Theme.of(context).colorScheme.tertiary;
        textColor = Theme.of(context).colorScheme.onTertiary;
        label = l10n.received;
        break;
      case 'CANCELLED':
        chipColor = Theme.of(context).colorScheme.error;
        textColor = Theme.of(context).colorScheme.onError;
        label = l10n.cancelled;
        break;
      default:
        chipColor = Theme.of(context).colorScheme.onSurface;
        textColor = Theme.of(context).colorScheme.onPrimary;
        label = status;
    }
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      backgroundColor: chipColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Stream<List<PurchasesWithSupplierAndWarehouse>> _watchPurchasesDetailed(
    AppDatabase db,
  ) {
    final query = db.select(db.purchases).join([
      drift.leftOuterJoin(
        db.suppliers,
        db.suppliers.id.equalsExp(db.purchases.supplierId),
      ),
      drift.leftOuterJoin(
        db.warehouses,
        db.warehouses.id.equalsExp(db.purchases.warehouseId),
      ),
    ])..orderBy([drift.OrderingTerm.desc(db.purchases.date)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return PurchasesWithSupplierAndWarehouse(
          purchase: row.readTable(db.purchases),
          supplier: row.readTableOrNull(db.suppliers),
          warehouse: row.readTableOrNull(db.warehouses),
        );
      }).toList();
    });
  }
}

class PurchasesWithSupplierAndWarehouse {
  final Purchase purchase;
  final Supplier? supplier;
  final Warehouse? warehouse;

  const PurchasesWithSupplierAndWarehouse({
    required this.purchase,
    this.supplier,
    this.warehouse,
  });
}
