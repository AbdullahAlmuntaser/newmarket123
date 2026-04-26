import 'dart:developer' as developer;
import 'package:uuid/uuid.dart';
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
  late String _unit;
  late String _cartonUnit;
  late int _piecesPerCarton;
  final MobileScannerController _scannerController = MobileScannerController();
  List<ProductUnit> _extraUnits = []; // إضافة قائمة الوحدات الإضافية

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
    _unit = widget.product?.unit ?? 'pcs';
    _cartonUnit = widget.product?.cartonUnit ?? 'carton';
    _piecesPerCarton = widget.product?.piecesPerCarton ?? 1;
    _loadExtraUnits();
  }

  Future<void> _loadExtraUnits() async {
    if (widget.product != null) {
      final db = Provider.of<AppDatabase>(context, listen: false);
      _extraUnits = await (db.select(db.productUnits)..where((t) => t.productId.equals(widget.product!.id))).get();
      setState(() {});
    }
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
              const Divider(),
              TextFormField(
                initialValue: _unit,
                decoration: InputDecoration(labelText: l10n.unit),
                onSaved: (value) => _unit = value ?? 'pcs',
              ),
              TextFormField(
                initialValue: _cartonUnit,
                decoration: InputDecoration(labelText: l10n.cartonUnit),
                onSaved: (value) => _cartonUnit = value ?? 'carton',
              ),
              TextFormField(
                initialValue: _piecesPerCarton.toString(),
                decoration: InputDecoration(labelText: l10n.piecesPerCarton),
                keyboardType: TextInputType.number,
                onSaved: (value) =>
                    _piecesPerCarton = int.tryParse(value!) ?? 1,
              ),
              const Divider(),
              Text('الوحدات الإضافية', style: Theme.of(context).textTheme.titleMedium),
              ..._extraUnits.map((u) => ListTile(
                title: Text(u.unitName),
                subtitle: Text('عامل التحويل: ${u.unitFactor}'),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _extraUnits.remove(u))),
              )),
              ElevatedButton(
                onPressed: _addNewUnit,
                child: const Text('إضافة وحدة جديدة'),
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

  void _addNewUnit() {
    final nameCtrl = TextEditingController();
    final factorCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة وحدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الوحدة')),
          TextField(controller: factorCtrl, decoration: const InputDecoration(labelText: 'عامل التحويل'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () {
            setState(() => _extraUnits.add(ProductUnit(
              id: const Uuid().v4(),
              productId: widget.product?.id ?? '',
              unitName: nameCtrl.text,
              unitFactor: double.tryParse(factorCtrl.text) ?? 1.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              syncStatus: 1,
              isDefault: false,
            )));
            Navigator.pop(context);
          }, child: const Text('إضافة')),
        ],
      ),
    );
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final db = Provider.of<AppDatabase>(context, listen: false);
      try {
        await db.transaction(() async {
          String productId;
          if (widget.product == null) {
            productId = await db.into(db.products).insertReturning(ProductsCompanion.insert(
              name: _name, sku: _skuController.text, unit: Value(_unit),
              cartonUnit: Value(_cartonUnit), piecesPerCarton: Value(_piecesPerCarton),
            )).then((p) => p.id);
          } else {
            productId = widget.product!.id;
            await db.update(db.products).replace(widget.product!.copyWith(
              name: _name, sku: _skuController.text, unit: _unit,
              cartonUnit: _cartonUnit, piecesPerCarton: _piecesPerCarton,
            ));
          }
          await (db.delete(db.productUnits)..where((t) => t.productId.equals(productId))).go();
          for (var u in _extraUnits) {
            await db.into(db.productUnits).insert(ProductUnitsCompanion.insert(
              productId: productId,
              unitName: u.unitName,
              unitFactor: Value(u.unitFactor),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ));
          }
        });
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
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
