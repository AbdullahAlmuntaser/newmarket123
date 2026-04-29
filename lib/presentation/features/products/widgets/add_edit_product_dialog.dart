import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AddEditProductDialog extends StatefulWidget {
  final Product? product;

  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _skuController;
  late TextEditingController _nameController;
  late TextEditingController _stockController;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _stockController = TextEditingController(text: widget.product?.stock.toString() ?? '0.0');
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.product == null ? l10n.addProduct : l10n.editProduct),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.productName),
                validator: (value) => value!.isEmpty ? l10n.enterProductName : null,
              ),
              TextFormField(
                controller: _skuController,
                decoration: InputDecoration(labelText: l10n.sku),
                validator: (value) => value!.isEmpty ? l10n.enterSku : null,
              ),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(labelText: l10n.stockLabel),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(onPressed: _saveProduct, child: Text(l10n.save)),
      ],
    );
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final initialStock = double.tryParse(_stockController.text) ?? 0.0;
      
      try {
        await db.transaction(() async {
          if (widget.product == null) {
            final productId = await db.into(db.products).insertReturning(ProductsCompanion.insert(
              name: _nameController.text, 
              sku: _skuController.text, 
              stock: Value(initialStock),
            )).then((p) => p.id);

            if (initialStock > 0) {
              final defaultWarehouse = await (db.select(db.warehouses)..where((w) => w.isDefault.equals(true))).getSingleOrNull();
              final warehouseId = defaultWarehouse?.id ?? 'default_warehouse_id';

              await db.into(db.inventoryTransactions).insert(InventoryTransactionsCompanion.insert(
                productId: productId,
                warehouseId: warehouseId, 
                quantity: initialStock,
                type: 'ADJUSTMENT',
                referenceId: productId,
              ));
            }
          }
        });
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
  }
}
