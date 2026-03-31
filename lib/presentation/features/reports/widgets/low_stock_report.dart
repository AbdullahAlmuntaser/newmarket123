import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class LowStockReport extends StatelessWidget {
  const LowStockReport({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lowStockProducts, // Will add to l10n
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Product>>(
              stream: db.watchLowStockProducts(), // Will add this method
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final products = snapshot.data ?? [];

                if (products.isEmpty) {
                  return Center(
                    child: Text(l10n.noLowStockProducts),
                  ); // Will add to l10n
                }

                return DataTable(
                  columns: [
                    DataColumn(label: Text(l10n.productName)),
                    DataColumn(label: Text(l10n.stockLabel), numeric: true),
                    DataColumn(label: Text(l10n.alertLimit), numeric: true),
                  ],
                  rows: products.map((product) {
                    return DataRow(
                      cells: [
                        DataCell(Text(product.name)),
                        DataCell(
                          Text(
                            product.stock.toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        DataCell(Text(product.alertLimit.toString())),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
