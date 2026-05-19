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
  late TextEditingController _buyPriceController;
  late TextEditingController _sellPriceController;
  late TextEditingController _wholesalePriceController;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _stockController =
        TextEditingController(text: widget.product?.stock.toString() ?? '0.0');
    _buyPriceController = TextEditingController(
        text: widget.product?.buyPrice.toString() ?? '0.0');
    _sellPriceController = TextEditingController(
        text: widget.product?.sellPrice.toString() ?? '0.0');
    _wholesalePriceController = TextEditingController(
        text: widget.product?.wholesalePrice.toString() ?? '0.0');
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _stockController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _wholesalePriceController.dispose();
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
                validator: (value) =>
                    value!.isEmpty ? l10n.enterProductName : null,
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _buyPriceController,
                decoration: InputDecoration(labelText: l10n.buyPrice),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellPriceController,
                decoration: InputDecoration(labelText: l10n.sellPrice),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _wholesalePriceController,
                decoration: InputDecoration(labelText: l10n.wholesalePrice),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(onPressed: _saveProduct, child: Text(l10n.save)),
      ],
    );
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final initialStock = double.tryParse(_stockController.text) ?? 0.0;
      final buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;
      final sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
      final wholesalePrice = double.tryParse(_wholesalePriceController.text) ?? 0.0;

      try {
        await db.transaction(() async {
          if (widget.product == null) {
            final productId = await db
                .into(db.products)
                .insertReturning(ProductsCompanion.insert(
                  name: _nameController.text,
                  sku: _skuController.text,
                  stock: Value(initialStock),
                  buyPrice: Value(buyPrice),
                  sellPrice: Value(sellPrice),
                  wholesalePrice: Value(wholesalePrice),
                ))
                .then((p) => p.id);

            if (initialStock > 0) {
              final defaultWarehouse = await (db.select(db.warehouses)
                    ..where((w) => w.isDefault.equals(true)))
                  .getSingleOrNull();
              final warehouseId =
                  defaultWarehouse?.id ?? 'default_warehouse_id';

              await db
                  .into(db.inventoryTransactions)
                  .insert(InventoryTransactionsCompanion.insert(
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
  }
}
