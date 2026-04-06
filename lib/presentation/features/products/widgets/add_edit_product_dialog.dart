import 'dart:developer' as developer;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/products/products_provider.dart';

class AddEditProductDialog extends StatefulWidget {
  final Product? product;

  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _skuController;
  late String _name;
  late String? _categoryId;
  late double _buyPrice;
  late double _sellPrice;
  late double _wholesalePrice;
  late double _stock;
  late double _alertLimit;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _name = widget.product?.name ?? '';
    _categoryId = widget.product?.categoryId;
    _buyPrice = widget.product?.buyPrice ?? 0.0;
    _sellPrice = widget.product?.sellPrice ?? 0.0;
    _wholesalePrice = widget.product?.wholesalePrice ?? 0.0;
    _stock = widget.product?.stock ?? 0.0;
    _alertLimit = widget.product?.alertLimit ?? 10.0;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: 400,
        child: Column(
          children: [
            AppBar(
              title: Text(AppLocalizations.of(context)!.scanBarcode),
              leading: const CloseButton(),
            ),
            Expanded(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _skuController.text = barcode.rawValue!;
                      });
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

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
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
                initialValue: _name,
                decoration: InputDecoration(labelText: l10n.productName),
                validator: (value) =>
                    value!.isEmpty ? l10n.enterProductName : null,
                onSaved: (value) => _name = value!,
              ),
              TextFormField(
                controller: _skuController,
                decoration: InputDecoration(
                  labelText: l10n.sku,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                    tooltip: l10n.scanBarcode,
                  ),
                ),
                validator: (value) => value!.isEmpty ? l10n.enterSku : null,
              ),
              StreamBuilder<List<Category>>(
                stream: db.select(db.categories).watch(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: InputDecoration(labelText: l10n.category),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                    onSaved: (value) => _categoryId = value,
                  );
                },
              ),
              TextFormField(
                initialValue: _buyPrice.toString(),
                decoration: InputDecoration(labelText: l10n.buyPrice),
                keyboardType: TextInputType.number,
                onSaved: (value) => _buyPrice = double.tryParse(value!) ?? 0.0,
              ),
              TextFormField(
                initialValue: _sellPrice.toString(),
                decoration: InputDecoration(labelText: l10n.sellPrice),
                keyboardType: TextInputType.number,
                onSaved: (value) => _sellPrice = double.tryParse(value!) ?? 0.0,
              ),
              TextFormField(
                initialValue: _wholesalePrice.toString(),
                decoration: InputDecoration(labelText: l10n.wholesalePrice),
                keyboardType: TextInputType.number,
                onSaved: (value) =>
                    _wholesalePrice = double.tryParse(value!) ?? 0.0,
              ),
              TextFormField(
                initialValue: _stock.toString(),
                decoration: InputDecoration(labelText: l10n.stockLabel),
                keyboardType: TextInputType.number,
                onSaved: (value) => _stock = double.tryParse(value!) ?? 0.0,
              ),
              TextFormField(
                initialValue: _alertLimit.toString(),
                decoration: InputDecoration(labelText: l10n.alertLimit),
                keyboardType: TextInputType.number,
                onSaved: (value) =>
                    _alertLimit = double.tryParse(value!) ?? 10.0,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.product != null)
          TextButton(
            onPressed: _deleteProduct,
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        TextButton(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(onPressed: _saveProduct, child: Text(l10n.save)),
      ],
    );
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final productsProvider = context.read<ProductsProvider>();
      final l10n = AppLocalizations.of(context)!;

      try {
        if (widget.product == null) {
          await productsProvider.addProduct(
            ProductsCompanion.insert(
              name: _name,
              sku: _skuController.text,
              categoryId: Value(_categoryId),
              buyPrice: Value(_buyPrice),
              sellPrice: Value(_sellPrice),
              wholesalePrice: Value(_wholesalePrice),
              stock: Value(_stock),
              alertLimit: Value(_alertLimit),
            ),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.productAdded)));
        } else {
          await productsProvider.updateProduct(
            widget.product!.copyWith(
              name: _name,
              sku: _skuController.text,
              categoryId: Value(_categoryId),
              buyPrice: _buyPrice,
              sellPrice: _sellPrice,
              wholesalePrice: _wholesalePrice,
              stock: _stock,
              alertLimit: _alertLimit,
            ),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.productUpdated)));
        }
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e, s) {
        developer.log(
          'Failed to save product',
          name: 'add_edit_product_dialog',
          error: e,
          stackTrace: s,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failedToSaveProduct}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _deleteProduct() async {
    final productsProvider = context.read<ProductsProvider>();
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteProductConfirmation(widget.product!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await productsProvider.deleteProduct(widget.product!);
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e, s) {
        developer.log(
          'Failed to delete product',
          name: 'add_edit_product_dialog',
          error: e,
          stackTrace: s,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failedToDeleteProduct}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
