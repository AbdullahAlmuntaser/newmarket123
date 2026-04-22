import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:supermarket/core/services/erp_data_service.dart';
import 'package:supermarket/presentation/features/purchases/widgets/purchase_item_row.dart';

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  Supplier? _selectedSupplier;
  SupplierSmartData? _supplierSmartData;
  Warehouse? _selectedWarehouse;
  DateTime _selectedDate = DateTime.now();
  String _paymentType = 'credit'; // cash / credit
  final List<PurchaseLineItem> _items = [];
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _customsDutyController = TextEditingController();
  final TextEditingController _otherExpensesController =
      TextEditingController();
  bool _isSaving = false;
  bool _isHeaderExpanded = true;
  bool _isExpensesExpanded = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _shippingCost =>
      double.tryParse(_shippingCostController.text) ?? 0.0;
  double get _otherExpenses =>
      double.tryParse(_otherExpensesController.text) ?? 0.0;
  double get _customsDuty =>
      double.tryParse(_customsDutyController.text) ?? 0.0;
  double get _total => _subtotal - _discount + _shippingCost + _otherExpenses + _customsDuty;

  @override
  void initState() {
    super.initState();
    _ensureDefaultWarehouse();
    _discountController.addListener(() => setState(() {}));
    _shippingCostController.addListener(() => setState(() {}));
    _otherExpensesController.addListener(() => setState(() {}));
    _customsDutyController.addListener(() => setState(() {}));
  }

  final TextEditingController _barcodeController = TextEditingController();

  Future<void> _onBarcodeSubmitted(String barcode, AppDatabase db) async {
    final products = await (db.select(db.products)
          ..where((p) => p.barcode.equals(barcode) | p.sku.equals(barcode)))
        .get();

    if (products.isNotEmpty) {
      final product = products.first;
      setState(() {
        _items.add(
          PurchaseLineItem(
            product: product,
            quantity: 1,
            price: product.buyPrice,
            selectedUnit: product.unit,
          ),
        );
      });
      _barcodeController.clear();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المنتج غير موجود')),
      );
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _supplierController.dispose();
    _discountController.dispose();
    _shippingCostController.dispose();
    _otherExpensesController.dispose();
    _customsDutyController.dispose();
    super.dispose();
  }

  Future<void> _fetchSupplierSmartData(String supplierId) async {
    final data = await sl<ErpDataService>().getSupplierSmartData(supplierId);
    setState(() {
      _supplierSmartData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة مشتريات'),
        actions: [
          IconButton(
            onPressed: () => _showLoadPODialog(db),
            icon: const Icon(Icons.download),
            tooltip: 'تحميل أمر شراء',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCollapsibleHeader(db),
                  _buildBarcodeSearch(db),
                  const Divider(),
                  _buildItemsList(db),
                  _buildAddItemButton(),
                  const Divider(),
                  _buildCollapsibleExpenses(),
                  _buildSummary(),
                ],
              ),
            ),
          ),
          _buildFooter(db),
        ],
      ),
    );
  }

  Widget _buildCollapsibleHeader(AppDatabase db) {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: _isHeaderExpanded,
        onExpansionChanged: (val) => setState(() => _isHeaderExpanded = val),
        title: Text(_selectedSupplier?.name ?? 'اختر المورد', 
          style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('التاريخ: ${_selectedDate.toString().split(' ')[0]} | ${_paymentType == 'cash' ? 'نقدي' : 'آجل'}'),
        leading: const Icon(Icons.business),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SupplierPicker(
                  db: db,
                  value: _selectedSupplier,
                  onChanged: (value) {
                    setState(() {
                      _selectedSupplier = value;
                      _supplierController.text = value?.name ?? '';
                    });
                    if (value != null) _fetchSupplierSmartData(value.id);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) setState(() => _selectedDate = date);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'التاريخ', border: OutlineInputBorder(), isDense: true),
                          child: Text(_selectedDate.toString().split(' ')[0]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'نوع الدفع', border: OutlineInputBorder(), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                          DropdownMenuItem(value: 'credit', child: Text('آجل')),
                        ],
                        onChanged: (value) => setState(() => _paymentType = value!),
                        initialValue: _paymentType,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                  StreamBuilder<List<Warehouse>>(
                  stream: db.select(db.warehouses).watch(),
                  builder: (context, snapshot) {
                    final warehouses = snapshot.data ?? [];
                    return DropdownButtonFormField<Warehouse>(
                      decoration: const InputDecoration(labelText: 'المستودع', border: OutlineInputBorder(), isDense: true),
                      items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                      onChanged: (value) => setState(() => _selectedWarehouse = value),
                      initialValue: _selectedWarehouse,
                    );
                  },
                ),
                if (_selectedSupplier != null && _supplierSmartData != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'رصيد المورد الحالي: ${_supplierSmartData!.currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeSearch(AppDatabase db) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _barcodeController,
        decoration: InputDecoration(
          labelText: 'مسح الباركود / البحث عن منتج',
          prefixIcon: const Icon(Icons.qr_code_scanner),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
        onSubmitted: (value) => _onBarcodeSubmitted(value, db),
      ),
    );
  }

  Widget _buildItemsList(AppDatabase db) {
    return FutureBuilder<List<Product>>(
      future: db.select(db.products).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final products = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            return Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.endToStart,
              background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
              onDismissed: (_) => setState(() => _items.removeAt(index)),
              child: PurchaseItemRow(
                index: index,
                item: _items[index],
                products: products,
                supplierId: _selectedSupplier?.id,
                onDelete: () => setState(() => _items.removeAt(index)),
                onChanged: () => setState(() {}),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddItemButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextButton.icon(
        onPressed: () => setState(() => _items.add(PurchaseLineItem())),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('إضافة منتج جديد للجدول'),
      ),
    );
  }

  Widget _buildCollapsibleExpenses() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        initiallyExpanded: _isExpensesExpanded,
        onExpansionChanged: (val) => setState(() => _isExpensesExpanded = val),
        title: const Text('المصاريف الإضافية والخصومات'),
        leading: const Icon(Icons.add_chart),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildExpenseField('الخصم', _discountController),
                _buildExpenseField('الشحن', _shippingCostController),
                _buildExpenseField('الجمارك', _customsDutyController),
                _buildExpenseField('مصاريف أخرى', _otherExpensesController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _summaryRow('المجموع الفرعي', _subtotal),
          _summaryRow('إجمالي المصاريف والخصم', _total - _subtotal),
          const Divider(),
          _summaryRow('الصافي النهائي', _total, isBold: true, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: isBold ? 18 : 14)),
      ],
    );
  }

  Widget _buildFooter(AppDatabase db) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))]),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: _isSaving ? null : () => _savePurchase(db, post: false), child: const Text('حفظ كمسودة'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: (_items.isEmpty || _selectedWarehouse == null || _isSaving) ? null : () => _savePurchase(db, post: true), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('ترحيل الفاتورة'))),
        ],
      ),
    );
  }

  // --- Utility methods ---
  Future<void> _showLoadPODialog(AppDatabase db) async {
    final pos = await (db.select(db.purchaseOrders)..where((t) => t.status.equals('APPROVED'))..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
    if (!mounted) return;
    if (pos.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد أوامر شراء معتمدة'))); return; }
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('اختيار أمر شراء'), content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: pos.length, itemBuilder: (context, index) { final po = pos[index]; return ListTile(title: Text('أمر رقم: ${po.orderNumber ?? po.id.substring(0, 8)}'), subtitle: Text('التاريخ: ${po.date.toString().split(' ')[0]} - الإجمالي: ${po.total}'), onTap: () { Navigator.pop(context); _loadPOItems(po, db); }); }))));
  }

  Future<void> _loadPOItems(PurchaseOrder po, AppDatabase db) async {
    final poItems = await db.purchasesDao.getPurchaseOrderItems(po.id);
    final products = await db.select(db.products).get();
    setState(() {
      _items.clear();
      for (var pi in poItems) { final product = products.firstWhere((p) => p.id == pi.productId); _items.add(PurchaseLineItem(product: product, quantity: pi.quantity, price: pi.price, selectedUnit: pi.unitId ?? product.unit)); }
      if (po.supplierId != null) { db.suppliersDao.getSupplierById(po.supplierId!).then((s) { if (s != null) { setState(() { _selectedSupplier = s; _supplierController.text = s.name; }); _fetchSupplierSmartData(s.id); } }); }
    });
  }

  Future<void> _ensureDefaultWarehouse() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final warehouses = await db.select(db.warehouses).get();
    if (warehouses.isEmpty) {
      final id = const Uuid().v4();
      await db.into(db.warehouses).insert(WarehousesCompanion.insert(id: drift.Value(id), name: 'Main Warehouse', isDefault: const drift.Value(true)));
      final updated = await db.select(db.warehouses).get();
      setState(() => _selectedWarehouse = updated.first);
    } else {
      setState(() => _selectedWarehouse = warehouses.firstWhere((w) => w.isDefault, orElse: () => warehouses.first));
    }
  }

  Future<void> _savePurchase(AppDatabase db, {required bool post}) async {
    if (_items.isEmpty || _selectedSupplier == null || _selectedWarehouse == null) return;
    setState(() => _isSaving = true);
    final purchaseId = const Uuid().v4();
    try {
      final purchaseCompanion = PurchasesCompanion.insert(id: drift.Value(purchaseId), supplierId: drift.Value(_selectedSupplier!.id), total: _total, discount: drift.Value(_discount), shippingCost: drift.Value(_shippingCost), otherExpenses: drift.Value(_otherExpenses), purchaseType: drift.Value(_paymentType), date: drift.Value(_selectedDate), isCredit: drift.Value(_paymentType == 'credit'), status: const drift.Value('DRAFT'), warehouseId: drift.Value(_selectedWarehouse!.id));
      final itemsCompanions = _items.map((item) => PurchaseItemsCompanion.insert(purchaseId: purchaseId, productId: item.product!.id, unitId: drift.Value(item.selectedUnit), quantity: item.quantity, unitPrice: item.price, price: item.lineTotal)).toList();
      await db.purchasesDao.createPurchase(purchaseCompanion: purchaseCompanion, itemsCompanions: itemsCompanions, userId: null);
      if (post) await sl<PurchaseService>().postPurchase(purchaseId: purchaseId, userId: null);
      if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(post ? 'تم ترحيل الفاتورة' : 'تم حفظ المسودة'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); } finally { setState(() => _isSaving = false); }
  }
}
