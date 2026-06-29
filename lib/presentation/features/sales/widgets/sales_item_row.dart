import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/sales/models/sales_line_item.dart';
import 'package:supermarket/presentation/widgets/money_form_field.dart';

class SalesItemRow extends StatefulWidget {
  final int index;
  final SalesLineItem item;
  final AppDatabase db;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final String? customerId;

  const SalesItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.db,
    required this.onDelete,
    required this.onChanged,
    this.customerId,
  });

  @override
  State<SalesItemRow> createState() => _SalesItemRowState();
}

class _SalesItemRowState extends State<SalesItemRow> {
  List<Product> _searchResults = [];

  Future<void> _searchProducts(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await (widget.db.select(widget.db.products)
            ..where((p) =>
                p.name.like('%$query%') |
                p.sku.like('%$query%') |
                p.barcode.like('%$query%'))
            ..limit(20))
          .get();
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      // Handle error if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text('${widget.index + 1}',
                        style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(
                    flex: 3,
                    child: Autocomplete<Product>(
                      displayStringForOption: (p) => p.name,
                      initialValue: TextEditingValue(
                          text: widget.item.product?.name ?? ''),
                      optionsBuilder: (v) {
                        if (v.text.isEmpty) return [];
                        _searchProducts(v.text);
                        return _searchResults;
                      },
                      onSelected: (p) {
                        setState(() {
                          widget.item.product = p;
                          widget.item.selectedUnit = p.unit;
                          widget.item.price = p.sellPrice.toDouble();
                        });
                        widget.onChanged();
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 8,
                            child: SizedBox(
                              height: 200,
                              child: ListView.builder(
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final product = options.elementAt(index);
                                  return ListTile(
                                    title: Text(product.name),
                                    subtitle: Text(
                                        'SKU: ${product.sku} | السعر: ${product.sellPrice}'),
                                    onTap: () => onSelected(product),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    )),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onDelete,
                  tooltip: 'حذف',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: widget.item.quantity.toString()),
                    onChanged: (v) {
                      final qty = double.tryParse(v);
                      if (qty != null && qty > 0) {
                        setState(() => widget.item.quantity = qty);
                        widget.onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MoneyFormField(
                    label: 'السعر',
                    decoration: const InputDecoration(
                      labelText: 'السعر',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    initialValue: widget.item.price.toString(),
                    onChanged: (v) {
                      final price = double.tryParse(v);
                      if (price != null) {
                        setState(() => widget.item.price = price);
                        widget.onChanged();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
