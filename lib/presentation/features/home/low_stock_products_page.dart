import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class LowStockProductsPage extends StatelessWidget {
  const LowStockProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lowStockItems)),
      body: StreamBuilder<List<Product>>(
        stream: db.productsDao.watchLowStockProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return Center(child: Text(l10n.noLowStockItems));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('SKU: ${product.sku}'),
                trailing: Chip(
                  backgroundColor: Colors.red[100],
                  label: Text(
                    '${l10n.stockLevel}: ${product.stock.toStringAsFixed(1)} / ${product.alertLimit.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
