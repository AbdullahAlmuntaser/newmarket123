import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/invoice_service.dart';

class SaleDetailsBottomSheet extends StatelessWidget {
  final Sale sale;
  final AppDatabase db;
  final AppLocalizations l10n;

  const SaleDetailsBottomSheet({
    super.key,
    required this.sale,
    required this.db,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => FutureBuilder<List<SaleItem>>(
        future: (db.select(
          db.saleItems,
        )..where((t) => t.saleId.equals(sale.id))).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(l10n.noItemsFound),
            ); // Assuming you have this localization
          }

          // Optimized product fetching: Fetch all products related to sale items in one go
          return FutureBuilder<List<Product>>(
            future:
                (db.select(db.products)..where(
                      (p) => p.id.isIn(items.map((i) => i.productId).toList()),
                    ))
                    .get(),
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = productSnapshot.data ?? [];
              final Map<String, Product> productMap = {
                for (var p in products) p.id: p,
              };

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
                        Row(
                          children: [
                            if (sale.status == 'POSTED')
                              IconButton(
                                icon: const Icon(
                                  Icons.assignment_return,
                                  color: Colors.orange,
                                ),
                                tooltip: 'إرجاع أصناف',
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.push(
                                    '/sales/returns/new',
                                    extra: sale.id,
                                  );
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf),
                              tooltip: l10n.viewInvoice,
                              onPressed: () => _viewInvoice(
                                context,
                                db,
                                sale,
                                items,
                                productMap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final product = productMap[item.productId];
                        return ListTile(
                          title: Text(
                            product?.name ?? l10n.unknownProduct,
                          ), // Assuming unknownProduct localization
                          subtitle: Text(
                            l10n.qtyAtPrice(
                              item.quantity.toString(),
                              item.price.toStringAsFixed(2),
                            ),
                          ),
                          trailing: Text(
                            (item.quantity * item.price).toStringAsFixed(2),
                          ),
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
          );
        },
      ),
    );
  }

  Future<void> _viewInvoice(
    BuildContext context,
    AppDatabase db,
    Sale sale,
    List<SaleItem> items,
    Map<String, Product> productMap,
  ) async {
    try {
      if (!context.mounted) return;

      final invoiceService = InvoiceService();
      final pdfData = await invoiceService.generateInvoice(
        sale: sale,
        items: items,
        products: productMap.values.toList(), // Pass products as a list
        companyName: 'My Supermarket',
        companyVatNumber: '1234567890',
      );

      await Printing.layoutPdf(onLayout: (format) => pdfData);
    } catch (e) {
      debugPrint("Invoice generation error: $e");
    }
  }
}
