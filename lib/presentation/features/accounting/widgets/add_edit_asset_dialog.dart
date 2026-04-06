import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/asset_provider.dart';
import 'package:uuid/uuid.dart';

class AddEditAssetDialog extends StatefulWidget {
  final AssetProvider assetProvider;
  final FixedAsset? asset; // Pass asset for editing

  const AddEditAssetDialog({super.key, required this.assetProvider, this.asset});

  @override
  State<AddEditAssetDialog> createState() => _AddEditAssetDialogState();
}

class _AddEditAssetDialogState extends State<AddEditAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _lifeController;
  late TextEditingController _salvageController;
  late DateTime _purchaseDate;

  bool get _isEditing => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _nameController = TextEditingController(text: asset?.name ?? '');
    _costController = TextEditingController(text: asset?.cost.toString() ?? '');
    _lifeController = TextEditingController(text: asset?.usefulLifeYears.toString() ?? '');
    _salvageController = TextEditingController(text: asset?.salvageValue.toString() ?? '');
    _purchaseDate = asset?.purchaseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _lifeController.dispose();
    _salvageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _purchaseDate) {
      setState(() {
        _purchaseDate = pickedDate;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final companion = FixedAssetsCompanion(
        id: _isEditing ? Value(widget.asset!.id) : Value(const Uuid().v4()),
        name: Value(_nameController.text),
        cost: Value(double.tryParse(_costController.text) ?? 0.0),
        usefulLifeYears: Value(int.tryParse(_lifeController.text) ?? 5),
        salvageValue: Value(double.tryParse(_salvageController.text) ?? 0.0),
        purchaseDate: Value(_purchaseDate),
        // Reset depreciation if cost or date changes, handled in provider
        accumulatedDepreciation: _isEditing ? const Value.absent() : const Value(0.0),
      );

      if (_isEditing) {
        // widget.assetProvider.updateAsset(companion);
      } else {
        widget.assetProvider.addAsset(companion);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'تعديل أصل' : 'إضافة أصل جديد'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الأصل', border: OutlineInputBorder()),
                validator: (value) => (value?.isEmpty ?? true) ? 'هذا الحقل مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(labelText: 'التكلفة', prefixIcon: Icon(Icons.monetization_on)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'هذا الحقل مطلوب';
                  if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lifeController,
                decoration: const InputDecoration(labelText: 'العمر الافتراضي (سنوات)', prefixIcon: Icon(Icons.hourglass_bottom)),
                keyboardType: TextInputType.number,
                validator: (value) {
                   if (value == null || value.isEmpty) return 'هذا الحقل مطلوب';
                  if (int.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salvageController,
                decoration: const InputDecoration(labelText: 'قيمة الخردة', prefixIcon: Icon(Icons.recycling)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                 validator: (value) {
                  if (value == null || value.isEmpty) return 'هذا الحقل مطلوب';
                  if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text('تاريخ الشراء: ${DateFormat('yyyy-MM-dd').format(_purchaseDate)}'),
                  const Spacer(),
                  TextButton(onPressed: _pickDate, child: const Text('تغيير')),
                ],
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _submit, child: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة')),
      ],
    );
  }
}
