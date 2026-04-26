import 'package:flutter/material.dart';

class AddUnitDialog extends StatefulWidget {
  final String productId;
  final String productName;

  const AddUnitDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<AddUnitDialog> createState() => _AddUnitDialogState();
}

class _AddUnitDialogState extends State<AddUnitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _unitNameController = TextEditingController();
  final _factorController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _unitNameController.dispose();
    _factorController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إضافة وحدة لـ ${widget.productName}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _unitNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الوحدة (مثلاً: كرتون)',
                ),
                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: _factorController,
                decoration: const InputDecoration(
                  labelText: 'المعامل (كم حبة تحتوي؟)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v ?? '') == null
                    ? 'أدخل رقماً صحيحاً'
                    : null,
              ),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'باركود الوحدة (اختياري)',
                ),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'سعر الوحدة (اختياري)',
                ),
                keyboardType: TextInputType.number,
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
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'unitName': _unitNameController.text,
                'factor': double.parse(_factorController.text),
                'barcode': _barcodeController.text.isEmpty
                    ? null
                    : _barcodeController.text,
                'sellPrice': _priceController.text.isEmpty
                    ? null
                    : double.parse(_priceController.text),
              });
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
