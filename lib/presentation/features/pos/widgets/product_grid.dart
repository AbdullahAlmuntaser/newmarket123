import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/logger.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';

class ProductGrid extends StatefulWidget {
  const ProductGrid({super.key});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  String _searchQuery = '';
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 16),
              FloatingActionButton(
                onPressed: _openScanner,
                tooltip: 'Scan Barcode',
                child: const Icon(Icons.qr_code_scanner),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream:
                (db.select(db.products)..where(
                      (t) =>
                          t.name.like('%${_searchQuery.toLowerCase()}%') |
                          t.sku.like('%$_searchQuery%'),
                    ))
                    .watch(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        context.read<PosBloc>().add(
                          AddProductBySku(product.sku),
                        );
                        HapticFeedback.selectionClick();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              color: HSLColor.fromColor(Theme.of(context).colorScheme.primaryContainer).withAlpha(0.3).toColor(),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.sellPrice.toStringAsFixed(2),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: 500,
        child: Column(
          children: [
            AppBar(
              title: const Text('Scan Barcode'),
              leading: const CloseButton(),
            ),
            Expanded(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      AppLogger.info('Barcode scanned: ${barcode.rawValue}');
                      HapticFeedback.heavyImpact(); // Feedback
                      context.read<PosBloc>().add(
                        AddProductBySku(barcode.rawValue!),
                      );
                      Navigator.pop(context);
                      break;
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
