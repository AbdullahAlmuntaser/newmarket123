import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class QuickProductAddDialog extends StatefulWidget {
  final Function(Product) onProductCreated;

  const QuickProductAddDialog({super.key, required this.onProductCreated});

  @override
  State<QuickProductAddDialog> createState() => _QuickProductAddDialogState();
}

class _QuickProductAddDialogState extends State<QuickProductAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _unitController = TextEditingController(text: 'حبة');

  Category? _selectedCategory;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final db = context.read<AppDatabase>();
    final productId = const Uuid().v4();

    try {
      final buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;
      final sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
      final sku = _barcodeController.text.isNotEmpty
          ? _barcodeController.text
          : productId.substring(0, 8);

      final companion = ProductsCompanion.insert(
        id: drift.Value(productId),
        name: _nameController.text,
        sku: sku,
        barcode: drift.Value(
          _barcodeController.text.isEmpty ? null : _barcodeController.text,
        ),
        categoryId: drift.Value(_selectedCategory?.id),
        unit: drift.Value(_unitController.text),
        buyPrice: drift.Value(buyPrice),
        sellPrice: drift.Value(sellPrice),
        wholesalePrice: const drift.Value(0.0),
        stock: const drift.Value(0.0),
        alertLimit: const drift.Value(5.0),
        taxRate: const drift.Value(15.0),
        isActive: const drift.Value(true),
        syncStatus: const drift.Value(1),
        updatedAt: drift.Value(DateTime.now()),
      );

      await db.into(db.products).insert(companion);

      // Fetch the created product to return it
      final createdProduct = await (db.select(
        db.products,
      )..where((t) => t.id.equals(productId))).getSingle();

      widget.onProductCreated(createdProduct);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في حفظ المنتج: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return AlertDialog(
      title: const Text('إضافة منتج جديد سريع'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم المنتج'),
                validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'الباركود / SKU'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _buyPriceController,
                      decoration: const InputDecoration(
                        labelText: 'سعر الشراء',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'خطأ' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _sellPriceController,
                      decoration: const InputDecoration(labelText: 'سعر البيع'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'خطأ' : null,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'الوحدة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StreamBuilder<List<Category>>(
                      stream: db.select(db.categories).watch(),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        return DropdownButtonFormField<Category>(
                          decoration: const InputDecoration(labelText: 'الفئة'),
                          items: categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveProduct,
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text('حفظ وإضافة للفاتورة'),
        ),
      ],
    );
  }
}
