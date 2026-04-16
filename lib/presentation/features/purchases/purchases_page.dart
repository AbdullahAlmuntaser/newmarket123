import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  final int _pageSize = 20;
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchasesHistory)),
      drawer: const MainDrawer(),
      body: FutureBuilder<List<PurchasesWithSupplierAndWarehouse>>(
        future: _fetchPurchases(db),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allPurchases = snapshot.data ?? [];
          if (allPurchases.isEmpty) {
            return Center(child: Text(l10n.noPurchasesFound));
          }

          final totalPages = (allPurchases.length / _pageSize).ceil();
          final start = _currentPage * _pageSize;
          final end = (start + _pageSize < allPurchases.length)
              ? start + _pageSize
              : allPurchases.length;
          final purchases = allPurchases.sublist(start, end);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: purchases.length,
                  itemBuilder: (context, index) {
                    final item = purchases[index];
                    final purchase = item.purchase;
                    final supplier = item.supplier;
                    final warehouse = item.warehouse;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                          '${NumberFormat.currency(symbol: '', decimalDigits: 2).format(purchase.total)} ${purchase.currencyId ?? 'USD'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () =>
                            context.push('/purchases/details/${purchase.id}'),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1) _buildPaginationControls(totalPages),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/purchases/new'),
        label: Text(l10n.newPurchase),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
          ),
          Text('صفحة ${_currentPage + 1} من $totalPages'),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage + 1 < totalPages
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  Future<List<PurchasesWithSupplierAndWarehouse>> _fetchPurchases(
    AppDatabase db,
  ) async {
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

    final rows = await query.get();
    return rows.map((row) {
      return PurchasesWithSupplierAndWarehouse(
        purchase: row.readTable(db.purchases),
        supplier: row.readTableOrNull(db.suppliers),
        warehouse: row.readTableOrNull(db.warehouses),
      );
    }).toList();
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
      label: Text(label, style: TextStyle(color: textColor, fontSize: 10)),
      backgroundColor: chipColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
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
