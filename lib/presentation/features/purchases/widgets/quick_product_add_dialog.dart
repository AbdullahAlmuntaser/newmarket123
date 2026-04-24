import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class QuickProductAddDialog extends StatefulWidget {
  final AppDatabase db;
  final Function(Product) onProductAdded;

  const QuickProductAddDialog({super.key, required this.db, required this.onProductAdded});

  @override
  State<QuickProductAddDialog> createState() => _QuickProductAddDialogState();
}

class _QuickProductAddDialogState extends State<QuickProductAddDialog> {
  final _nameController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _unitController = TextEditingController(text: 'حبة');
  
  bool _isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _buyPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم المنتج وسعر الشراء')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final newProduct = ProductsCompanion.insert(
        name: _nameController.text,
        sku: const Uuid().v4().substring(0, 8),
        buyPrice: drift.Value(double.tryParse(_buyPriceController.text) ?? 0.0),
        sellPrice: drift.Value(double.tryParse(_sellPriceController.text) ?? 0.0),
        unit: drift.Value(_unitController.text),
        stock: const drift.Value(0.0),
        alertLimit: const drift.Value(10.0),
        taxRate: const drift.Value(0.0),
      );

      final id = await widget.db.into(widget.db.products).insert(newProduct);
      final product = await (widget.db.select(widget.db.products)..where((p) => p.id.equals(id.toString()))).getSingle();
      
      widget.onProductAdded(product);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة منتج جديد سريعاً'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المنتج')),
            TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'الوحدة الأساسية')),
            TextField(controller: _buyPriceController, decoration: const InputDecoration(labelText: 'سعر الشراء'), keyboardType: TextInputType.number),
            TextField(controller: _sellPriceController, decoration: const InputDecoration(labelText: 'سعر البيع'), keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _isLoading ? null : _save, child: _isLoading ? const CircularProgressIndicator() : const Text('حفظ')),
      ],
    );
  }
}
