import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:printing/printing.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/core/services/invoice_service.dart';

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
        stream: (db.select(db.sales)..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])).watch(),
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
                  backgroundColor: sale.paymentMethod == 'cash'
                      ? Colors.green.withAlpha(26)
                      : Colors.blue.withAlpha(26),
                  child: Icon(
                    sale.paymentMethod == 'cash' ? Icons.money : Icons.credit_card,
                    color: sale.paymentMethod == 'cash' ? Colors.green : Colors.blue,
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
                      '${sale.total}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      sale.syncStatus == 0 ? l10n.synced : l10n.pending,
                      style: TextStyle(
                        fontSize: 10,
                        color: sale.syncStatus == 0 ? Colors.green : Colors.orange,
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => FutureBuilder<List<SaleItem>>(
          future: (db.select(db.saleItems)..where((t) => t.saleId.equals(sale.id))).get(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.saleDetails,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        tooltip: 'View Invoice',
                        onPressed: () => _viewInvoice(context, db, sale, items),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return FutureBuilder<Product?>(
                        future: (db.select(db.products)..where((t) => t.id.equals(item.productId))).getSingleOrNull(),
                        builder: (context, pSnapshot) {
                          final product = pSnapshot.data;
                          return ListTile(
                            title: Text(product?.name ?? l10n.loading),
                            subtitle: Text(
                              l10n.qtyAtPrice(
                                item.quantity.toString(),
                                item.price.toString(),
                              ),
                            ),
                            trailing: Text(
                              (item.quantity * item.price).toStringAsFixed(2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.total,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        sale.total.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _viewInvoice(
    BuildContext context,
    AppDatabase db,
    Sale sale,
    List<SaleItem> items,
  ) async {
    try {
      final products = await (db.select(db.products)..where((p) => p.id.isIn(items.map((i) => i.productId).toList()))).get();

      if (!context.mounted) return;

      final itemsWithProduct = items.map((item) {
        final product = products.firstWhere((p) => p.id == item.productId);
        return SaleItemWithProduct(
          product: product,
          quantity: item.quantity,
          price: item.price,
        );
      }).toList();

      final file = await InvoiceService.generateInvoice(
        context,
        sale: sale,
        items: itemsWithProduct,
        companyName: 'My Supermarket',
        vatNumber: '1234567890',
      );

      await Printing.layoutPdf(
        onLayout: (format) => file.readAsBytes(),
      );
    } catch (e) {
      debugPrint("Invoice generation error: $e");
    }
  }
}
