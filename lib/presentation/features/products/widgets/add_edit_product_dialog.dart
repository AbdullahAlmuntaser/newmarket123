import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/product_image_service.dart';
import 'package:supermarket/core/services/barcode_generation_service.dart';

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
  late TextEditingController _barcodeController;
  String? _imagePath;
  String? _selectedCategoryId;
  List<Category> _categories = [];

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
    _barcodeController =
        TextEditingController(text: widget.product?.barcode ?? '');
    _imagePath = widget.product?.imagePath;
    _selectedCategoryId = widget.product?.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final list = await db.select(db.categories).get();
    if (mounted) {
      setState(() {
        _categories = list;
        if (_selectedCategoryId != null &&
            !list.any((c) => c.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _stockController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _wholesalePriceController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ProductImageService.pickImage(source: source);
    if (file != null && mounted) {
      setState(() => _imagePath = file.path);
    }
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
              _buildImageSection(),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'الفئة / التصنيف'),
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'الباركود',
                        hintText: 'اتركه فارغاً للتوليد التلقائي',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code, size: 20),
                    onPressed: () {
                      _barcodeController.text =
                          BarcodeGenerationService.autoGenerateBarcode();
                    },
                    tooltip: 'توليد باركود تلقائي',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: l10n.stockLabel,
                  helperText: widget.product != null ? 'تعديل المخزون يتم عبر الجرد أو التحويل' : null,
                ),
                keyboardType: TextInputType.number,
                readOnly: widget.product != null,
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

  Widget _buildImageSection() {
    return Column(
      children: [
        if (_imagePath != null && _imagePath!.isNotEmpty)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_imagePath!),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 40),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _imagePath = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 4),
                Text('صورة المنتج',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('المعرض'),
            ),
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('الكاميرا'),
            ),
          ],
        ),
      ],
    );
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final initialStock =
          Decimal.tryParse(_stockController.text) ?? Decimal.zero;
      final buyPrice =
          Decimal.tryParse(_buyPriceController.text) ?? Decimal.zero;
      final sellPrice =
          Decimal.tryParse(_sellPriceController.text) ?? Decimal.zero;
      final wholesalePrice =
          Decimal.tryParse(_wholesalePriceController.text) ?? Decimal.zero;

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
                  barcode: Value(_barcodeController.text.isNotEmpty
                      ? _barcodeController.text
                      : null),
                  categoryId: Value(_selectedCategoryId),
                ))
                .then((p) => p.id);

            if (_imagePath != null) {
              await (db.update(db.products)
                    ..where((p) => p.id.equals(productId)))
                  .write(
                ProductsCompanion(imagePath: Value(_imagePath)),
              );
            }

            if (initialStock > Decimal.zero) {
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
                    quantity: Value(initialStock),
                    type: 'ADJUSTMENT',
                    referenceId: productId,
                  ));
            }
          } else {
            await (db.update(db.products)
                  ..where((p) => p.id.equals(widget.product!.id)))
                .write(
              ProductsCompanion(
                name: Value(_nameController.text),
                sku: Value(_skuController.text),
                buyPrice: Value(buyPrice),
                sellPrice: Value(sellPrice),
                wholesalePrice: Value(wholesalePrice),
                imagePath: Value(_imagePath),
                barcode: Value(_barcodeController.text.isNotEmpty
                    ? _barcodeController.text
                    : null),
                categoryId: Value(_selectedCategoryId),
              ),
            );
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
