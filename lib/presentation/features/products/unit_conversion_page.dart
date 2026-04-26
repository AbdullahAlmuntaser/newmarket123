import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;

class UnitConversionPage extends StatefulWidget {
  final String productId;
  final String productName;

  const UnitConversionPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<UnitConversionPage> createState() => _UnitConversionPageState();
}

class _UnitConversionPageState extends State<UnitConversionPage> {
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

  Future<void> _addConversion() async {
    if (_formKey.currentState!.validate()) {
      final db = context.read<AppDatabase>();
      await db
          .into(db.unitConversions)
          .insert(
            UnitConversionsCompanion.insert(
              productId: widget.productId,
              unitName: _unitNameController.text,
              factor: double.parse(_factorController.text),
              barcode: drift.Value(
                _barcodeController.text.isEmpty
                    ? null
                    : _barcodeController.text,
              ),
              sellPrice: drift.Value(
                _priceController.text.isEmpty
                    ? null
                    : double.parse(_priceController.text),
              ),
            ),
          );

      _unitNameController.clear();
      _factorController.clear();
      _barcodeController.clear();
      _priceController.clear();

      if (mounted) {
        Navigator.pop(context);
        setState(() {}); // Refresh list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: Text('تحويل الوحدات: ${widget.productName}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<UnitConversion>>(
              stream: (db.select(
                db.unitConversions,
              )..where((t) => t.productId.equals(widget.productId))).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final conversions = snapshot.data!;
                if (conversions.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد تحويلات مضافة بعد.'),
                  );
                }

                return ListView.builder(
                  itemCount: conversions.length,
                  itemBuilder: (context, index) {
                    final conv = conversions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          '${conv.unitName} (المعامل: ${conv.factor})',
                        ),
                        subtitle: Text(
                          'باركود: ${conv.barcode ?? "لا يوجد"} | السعر: ${conv.sellPrice ?? "افتراضي"}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await (db.delete(
                              db.unitConversions,
                            )..where((t) => t.id.equals(conv.id))).go();
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        label: const Text('إضافة وحدة تحويل'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة وحدة تحويل جديدة'),
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
          ElevatedButton(onPressed: _addConversion, child: const Text('حفظ')),
        ],
      ),
    );
  }
}
