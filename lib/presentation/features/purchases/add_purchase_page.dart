import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:uuid/uuid.dart';
import 'purchase_provider.dart';

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  Supplier? _selectedSupplier;
  final DateTime _selectedDate = DateTime.now();
  final List<PurchaseItemData> _items = [];

  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _otherExpensesController = TextEditingController();

  bool _isSaving = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + (item.subtotal));
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _shippingCost => double.tryParse(_shippingCostController.text) ?? 0.0;
  double get _otherExpenses => double.tryParse(_otherExpensesController.text) ?? 0.0;
  double get _total => _subtotal - _discount + _shippingCost + _otherExpenses;

  @override
  void dispose() {
    _discountController.dispose();
    _shippingCostController.dispose();
    _otherExpensesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مشتريات')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Assuming SupplierPicker exists. If not, it needs to be imported or handled.
                  // SupplierPicker(db: db, value: _selectedSupplier, onChanged: (v) => setState(() => _selectedSupplier = v)),
                  const SizedBox(height: 12),
                  _buildSummary(),
                ],
              ),
            ),
            _buildFooter(db),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('الإجمالي: ${_total.toStringAsFixed(2)}')));

  Widget _buildFooter(AppDatabase db) => ElevatedButton(
    onPressed: _isSaving ? null : () => _savePurchase(db, post: true),
    child: _isSaving ? const CircularProgressIndicator() : const Text('حفظ وترحيل'),
  );

  Future<void> _savePurchase(AppDatabase db, {required bool post}) async {
    if (!_formKey.currentState!.validate() || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة البيانات وإضافة أصناف')));
      return;
    }
    setState(() => _isSaving = true);
    final purchaseId = const Uuid().v4();
    try {
      await db.transaction(() async {
        // تجهيز عناصر الفاتورة
        final itemsCompanions = _items.map((item) => PurchaseItemsCompanion.insert(
          purchaseId: purchaseId,
          productId: item.product.id, // تم التصحيح هنا
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          unitFactor: drift.Value(item.selectedUnit?.factor ?? 1.0), // تم التصحيح هنا
          price: item.subtotal,
        )).toList();

        await db.purchasesDao.createPurchase(
          purchaseCompanion: PurchasesCompanion.insert(
            id: drift.Value(purchaseId),
            supplierId: drift.Value(_selectedSupplier?.id ?? ''),
            total: _total,
            discount: drift.Value(_discount),
            date: drift.Value(_selectedDate),
            status: const drift.Value('DRAFT'),
          ),
          itemsCompanions: itemsCompanions,
          userId: null,
        );
        if (post) await sl<PurchaseService>().postPurchase(purchaseId);
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
