import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  Supplier? _selectedSupplier;
  final List<_PurchaseLineItem> _items = [];
  final TextEditingController _invoiceController = TextEditingController();
  bool _isSaving = false;
  bool _isCreditPurchase = true; // Default to credit purchase

  double get _total =>
      _items.fold(0, (sum, item) => sum + (item.quantity * item.price));

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newPurchaseInvoice)),
      body: Column(
        children: [
          _buildHeader(db),
          const Divider(),
          _buildItemsList(db),
          _buildFooter(db),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(db),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          StreamBuilder<List<Supplier>>(
            stream: db.select(db.suppliers).watch(),
            builder: (context, snapshot) {
              final suppliers = snapshot.data ?? [];
              return DropdownButtonFormField<Supplier>(
                initialValue: _selectedSupplier,
                decoration: InputDecoration(
                  labelText: l10n.selectSupplier,
                  border: const OutlineInputBorder(),
                ),
                items: suppliers
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSupplier = value),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _invoiceController,
            decoration: InputDecoration(
              labelText: l10n.invoiceNumberLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    return Expanded(
      child: _items.isEmpty
          ? Center(child: Text(l10n.noProductsAdded))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  title: Text(item.product.name),
                  subtitle: Text(l10n.qtyAtPrice(item.quantity, item.price)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.quantity * item.price}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _items.removeAt(index)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFooter(AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.total}:',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_total',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            title: const Text('شراء آجل (على الحساب)'),
            value: _isCreditPurchase,
            onChanged: (bool? value) {
              setState(() {
                _isCreditPurchase = value ?? true;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  (_items.isEmpty || _selectedSupplier == null || _isSaving)
                  ? null
                  : () => _savePurchase(db),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(l10n.savePurchase),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(AppDatabase db) async {
    final result = await showDialog<_PurchaseLineItem>(
      context: context,
      builder: (context) => _AddProductToPurchaseDialog(db: db),
    );
    if (result != null) {
      setState(() => _items.add(result));
    }
  }

  Future<void> _savePurchase(AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    final purchaseId = const Uuid().v4();

    try {
      await db.transaction(() async {
        // 1. Create Purchase
        await db
            .into(db.purchases)
            .insert(
              PurchasesCompanion.insert(
                id: drift.Value(purchaseId),
                supplierId: drift.Value(_selectedSupplier!.id),
                total: _total,
                invoiceNumber: drift.Value(_invoiceController.text),
                isCredit: drift.Value(_isCreditPurchase),
                syncStatus: const drift.Value(1),
              ),
            );

        // 2. Create Items and Update Stock
        for (var item in _items) {
          await db
              .into(db.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  productId: item.product.id,
                  quantity: item.quantity,
                  price: item.price,
                  syncStatus: const drift.Value(1),
                ),
              );

          final newStock = item.product.stock + item.quantity;
          await (db.update(db.products)
                ..where((t) => t.id.equals(item.product.id)))
              .write(ProductsCompanion(stock: drift.Value(newStock)));
        }

        // 3. Update Supplier Balance if it's a credit purchase
        if (_isCreditPurchase) {
          final newBalance = _selectedSupplier!.balance + _total;
          await (db.update(db.suppliers)
                ..where((t) => t.id.equals(_selectedSupplier!.id)))
              .write(SuppliersCompanion(balance: drift.Value(newBalance)));
        }

        // 4. Add to Sync Queue
        final payload = {
          'id': purchaseId,
          'supplierId': _selectedSupplier!.id,
          'total': _total,
          'isCredit': _isCreditPurchase,
          'items': _items
              .map(
                (i) => {
                  'productId': i.product.id,
                  'qty': i.quantity,
                  'price': i.price,
                },
              )
              .toList(),
        };
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                entityTable: 'purchases',
                entityId: purchaseId,
                operation: 'create',
                payload: jsonEncode(payload),
              ),
            );
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.purchaseSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _PurchaseLineItem {
  final Product product;
  final double quantity;
  final double price;
  _PurchaseLineItem({
    required this.product,
    required this.quantity,
    required this.price,
  });
}

class _AddProductToPurchaseDialog extends StatefulWidget {
  final AppDatabase db;
  const _AddProductToPurchaseDialog({required this.db});

  @override
  State<_AddProductToPurchaseDialog> createState() =>
      _AddProductToPurchaseDialogState();
}

class _AddProductToPurchaseDialogState
    extends State<_AddProductToPurchaseDialog> {
  Product? _selectedProduct;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addProductToPurchase),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<List<Product>>(
            stream: widget.db.select(widget.db.products).watch(),
            builder: (context, snapshot) {
              final products = snapshot.data ?? [];
              return DropdownButtonFormField<Product>(
                decoration: InputDecoration(labelText: l10n.productLabel),
                items: products
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProduct = value;
                    _priceController.text = value?.buyPrice.toString() ?? '';
                  });
                },
              );
            },
          ),
          TextField(
            controller: _qtyController,
            decoration: InputDecoration(labelText: l10n.quantityLabel),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _priceController,
            decoration: InputDecoration(labelText: l10n.buyPriceLabel),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel.toUpperCase()),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedProduct != null) {
              Navigator.pop(
                context,
                _PurchaseLineItem(
                  product: _selectedProduct!,
                  quantity: double.tryParse(_qtyController.text) ?? 0.0,
                  price: double.tryParse(_priceController.text) ?? 0.0,
                ),
              );
            }
          },
          child: Text(l10n.add.toUpperCase()),
        ),
      ],
    );
  }
}
