import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.productWithCategory,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductWithCategory productWithCategory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final product = productWithCategory.product;
    final categoryName = productWithCategory.category?.name ?? l10n.unknown;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.skuLabel}: ${product.sku}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${l10n.categoryLabel}: $categoryName',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${l10n.stockLabel}: ${product.stock}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${l10n.sellPriceLabel}: ${product.sellPrice.toStringAsFixed(2)} ${l10n.currencySymbol}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.straighten_rounded,
                    color: Colors.orange,
                  ),
                  onPressed: () => context.push(
                    '/products/unit-conversion/${product.id}',
                    extra: product.name,
                  ),
                  tooltip: 'تحويل الوحدات',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: onEdit,
                  tooltip: l10n.edit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: onDelete,
                  tooltip: l10n.delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
