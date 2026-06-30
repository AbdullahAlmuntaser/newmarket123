import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/app_config_service.dart';

class PosProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const PosProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final packagingEngine = context.read<PackagingEngine>();

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildProductImage(context),
              ),
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FutureBuilder<bool>(
                      future: sl<AppConfigService>().hideSalePrices(),
                      builder: (context, snapshot) {
                        final hide = snapshot.data ?? false;
                        if (hide) {
                          return const Text(
                            '***',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          );
                        }
                        return Text(
                          '${product.sellPrice.toStringAsFixed(2)} ${l10n.currencySymbol}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  FutureBuilder<String>(
                      future: packagingEngine.formatInventoryBalance(
                          product.id, product.stock),
                      builder: (context, snapshot) {
                        final balanceText =
                            snapshot.data ?? product.stock.toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.stock > Decimal.zero
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            balanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(BuildContext context) {
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      final file = File(product.imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultIcon(context),
          ),
        );
      }
    }
    return _defaultIcon(context);
  }

  Widget _defaultIcon(BuildContext context) {
    return Center(
      child: Icon(
        Icons.inventory_2,
        size: 40,
        color: Theme.of(context).primaryColor.withOpacity(0.5),
      ),
    );
  }
}
