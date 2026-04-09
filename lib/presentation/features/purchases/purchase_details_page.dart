import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class PurchaseDetailsPage extends StatelessWidget {
  final String purchaseId;
  const PurchaseDetailsPage({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseDetails)),
      body: FutureBuilder<PurchaseWithSupplier?>(
        future: _getPurchaseDetails(db),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(child: Text(l10n.purchaseNotFound));
          }

          final purchase = data.purchase;
          final supplier = data.supplier;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(context, purchase, supplier, l10n),
                const SizedBox(height: 24),
                Text(
                  l10n.items,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildItemsList(db, l10n),
                const SizedBox(height: 24),
                _buildTotals(context, purchase, l10n),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    Purchase purchase,
    Supplier? supplier,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(l10n.purchaseId, purchase.id.substring(0, 8)),
            _buildInfoRow(l10n.date, DateFormat.yMMMd().format(purchase.date)),
            _buildInfoRow(l10n.supplier, supplier?.name ?? l10n.unknown),
            _buildInfoRow(
              l10n.invoiceNumberLabel,
              purchase.invoiceNumber ?? '-',
            ),
            _buildInfoRow(l10n.status, purchase.status),
            _buildInfoRow(
              l10n.paymentMethod,
              purchase.isCredit ? l10n.credit : l10n.cash,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildItemsList(AppDatabase db, AppLocalizations l10n) {
    return FutureBuilder<List<PurchaseItemWithProduct>>(
      future: _getPurchaseItems(db),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final items = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.product?.name ?? item.item.productId),
              subtitle: Text(
                '${item.item.quantity} x ${item.item.price.toStringAsFixed(2)}',
              ),
              trailing: Text(
                (item.item.quantity * item.item.price).toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTotals(
    BuildContext context,
    Purchase purchase,
    AppLocalizations l10n,
  ) {
    final subtotal = purchase.total - purchase.tax;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(l10n.subtotal, subtotal.toStringAsFixed(2)),
          _buildInfoRow(l10n.tax, purchase.tax.toStringAsFixed(2)),
          const Divider(),
          _buildInfoRow(l10n.total, purchase.total.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Future<PurchaseWithSupplier?> _getPurchaseDetails(AppDatabase db) async {
    final purchase = await (db.select(
      db.purchases,
    )..where((t) => t.id.equals(purchaseId))).getSingleOrNull();
    if (purchase == null) return null;
    Supplier? supplier;
    if (purchase.supplierId != null) {
      supplier = await (db.select(
        db.suppliers,
      )..where((t) => t.id.equals(purchase.supplierId!))).getSingleOrNull();
    }
    return PurchaseWithSupplier(purchase, supplier);
  }

  Future<List<PurchaseItemWithProduct>> _getPurchaseItems(
    AppDatabase db,
  ) async {
    final items = await (db.select(
      db.purchaseItems,
    )..where((t) => t.purchaseId.equals(purchaseId))).get();
    final List<PurchaseItemWithProduct> result = [];
    for (var item in items) {
      final product = await (db.select(
        db.products,
      )..where((t) => t.id.equals(item.productId))).getSingleOrNull();
      result.add(PurchaseItemWithProduct(item, product));
    }
    return result;
  }
}

class PurchaseWithSupplier {
  final Purchase purchase;
  final Supplier? supplier;
  PurchaseWithSupplier(this.purchase, this.supplier);
}

class PurchaseItemWithProduct {
  final PurchaseItem item;
  final Product? product;
  PurchaseItemWithProduct(this.item, this.product);
}
