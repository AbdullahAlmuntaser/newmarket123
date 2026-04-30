import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:uuid/uuid.dart';
import 'purchase_provider.dart';
import '../../widgets/entity_picker.dart';
import 'widgets/purchase_item_row.dart';
import 'widgets/quick_product_add_dialog.dart';

import 'package:supermarket/core/services/grn_service.dart';

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  Supplier? _selectedSupplier;
  Warehouse? _selectedWarehouse;
  String _paymentMethod = 'cash';
  Currency? _selectedCurrency;
  
  final DateTime _selectedDate = DateTime.now();
  final List<PurchaseItemData> _items = [];

  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _otherExpensesController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();

  bool _isSaving = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + (item.subtotal));
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _shippingCost => double.tryParse(_shippingCostController.text) ?? 0.0;
  double get _otherExpenses => double.tryParse(_otherExpensesController.text) ?? 0.0;
  double get _tax => double.tryParse(_taxController.text) ?? 0.0;
  double get _total => _subtotal - _discount + _shippingCost + _otherExpenses + _tax;

  @override
  void dispose() {
    _discountController.dispose();
    _shippingCostController.dispose();
    _otherExpensesController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مشتريات')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(db),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (ctx, i) => PurchaseItemRow(
                index: i,
                item: _items[i],
                products: const [],
                onChanged: () => setState(() {}),
                onDelete: () => setState(() => _items.removeAt(i)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showProductPicker(db),
                  icon: const Icon(Icons.search),
                  label: const Text('إضافة صنف موجود'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showQuickAddProduct(db),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('إضافة صنف جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummary(),

          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(db),
    );
  }

  Widget _buildHeader(AppDatabase db) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: SupplierPicker(db: db, value: _selectedSupplier, onChanged: (v) => setState(() => _selectedSupplier = v))),
            Expanded(child: WarehousePicker(db: db, value: _selectedWarehouse, onChanged: (v) => setState(() => _selectedWarehouse = v))),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _paymentMethod,
                items: ['cash', 'credit'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              ),
            ),
            Expanded(child: CurrencyPicker(db: db, value: _selectedCurrency, onChanged: (v) => setState(() => _selectedCurrency = v))),
          ],
        ),
      ],
    ),
  );

  Future<void> _showProductPicker(AppDatabase db) async {
    final product = await showDialog<Product>(
      context: context,
      builder: (context) => EntityPicker<Product>(
        stream: db.productsDao.watchAllProducts(),
        title: 'اختر منتج',
        builder: (p) => Text(p.name),
      ),
    );
    if (product != null) {
      setState(() {
        _items.add(PurchaseItemData(
          product: product,
          quantity: 1.0,
          unitPrice: product.buyPrice,
        ));
      });
    }
  }

  void _showQuickAddProduct(AppDatabase db) {
    showDialog(
      context: context,
      builder: (context) => QuickProductAddDialog(
        onProductCreated: (product) {
          setState(() {
            _items.add(PurchaseItemData(
              product: product,
              quantity: 1.0,
              unitPrice: product.buyPrice,
            ));
          });
        },
      ),
    );
  }

  Widget _buildSummary() => Card(
    margin: const EdgeInsets.all(8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRow('الإجمالي الفرعي', _subtotal),
          _buildEditableRow('الضريبة', _taxController),
          _buildEditableRow('الخصم', _discountController),
          _buildEditableRow('الشحن', _shippingCostController),
          _buildEditableRow('مصاريف أخرى', _otherExpensesController),
          const Divider(),
          _buildRow('الإجمالي النهائي', _total, isBold: true),
        ],
      ),
    ),
  );

  Widget _buildRow(String title, double value, {bool isBold = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
    ],
  );

  Widget _buildEditableRow(String title, TextEditingController controller) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title),
      SizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(isDense: true),
          onChanged: (_) => setState(() {}),
        ),
      ),
    ],
  );

  Widget _buildFooter(AppDatabase db) => ElevatedButton(
    onPressed: _isSaving ? null : () => _savePurchase(db, post: true),
    child: _isSaving ? const CircularProgressIndicator() : const Text('حفظ وترحيل'),
  );

  Future<void> _savePurchase(AppDatabase db, {required bool post}) async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار مورد')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إضافة أصناف')));
      return;
    }
    setState(() => _isSaving = true);
    final purchaseId = const Uuid().v4();
    try {
      final purchaseService = sl<PurchaseService>();
      final grnService = sl<GrnService>();

      await db.transaction(() async {
        final itemsCompanions = _items.map((item) => PurchaseItemsCompanion.insert(
          purchaseId: purchaseId,
          productId: item.product.id,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          unitFactor: drift.Value(item.selectedUnit?.factor ?? 1.0),
          price: item.subtotal,
          batchNumber: drift.Value(item.batchNumber),
          expiryDate: drift.Value(item.expiryDate),
        )).toList();

        await db.purchasesDao.createPurchase(
          purchaseCompanion: PurchasesCompanion.insert(
            id: drift.Value(purchaseId),
            supplierId: drift.Value(_selectedSupplier?.id ?? ''),
            warehouseId: drift.Value(_selectedWarehouse?.id),
            total: _total,
            discount: drift.Value(_discount),
            tax: drift.Value(_tax),
            shippingCost: drift.Value(_shippingCost),
            otherExpenses: drift.Value(_otherExpenses),
            date: drift.Value(_selectedDate),
            status: const drift.Value('DRAFT'),
          ),
          itemsCompanions: itemsCompanions,
          userId: null,
        );

        if (post) {
          // 1. Create GRN (Automatically updates Inventory Stock and BuyPrice)
          await grnService.createGrnFromPurchase(
            purchaseId: purchaseId,
            warehouseId: _selectedWarehouse?.id ?? 'default_warehouse', // Fallback or handle null
            notes: 'Auto-generated from Invoice',
          );

          // 2. Post Purchase (Updates Accounting/GLEntries)
          await purchaseService.postPurchase(purchaseId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ وترحيل الفاتورة وتحديث المخزون بنجاح')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
