import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/features/sales/widgets/sale_details_bottom_sheet.dart'; // Import the new widget

class SalesHistoryPage extends StatelessWidget {
  const SalesHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sales)),
      drawer: const MainDrawer(),
      body: StreamBuilder<List<Sale>>(
        stream: (db.select(
          db.sales,
        )..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sales = snapshot.data ?? [];
          if (sales.isEmpty) {
            return Center(child: Text(l10n.noSalesFound));
          }
          return ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    sale.paymentMethod == 'cash'
                        ? Icons.money
                        : Icons.credit_card,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(l10n.saleIdLabel(sale.id.substring(0, 8))),
                subtitle: Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(sale.createdAt),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      sale.total.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      sale.syncStatus == 0 ? l10n.synced : l10n.pending,
                      style: TextStyle(
                        fontSize: 10,
                        color: sale.syncStatus == 0
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
                onTap: () => _showSaleDetails(context, db, sale, l10n),
              );
            },
          );
        },
      ),
    );
  }

  void _showSaleDetails(
    BuildContext context,
    AppDatabase db,
    Sale sale,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SaleDetailsBottomSheet(
        sale: sale,
        db: db,
        l10n: l10n,
      ),
    );
  }
}
