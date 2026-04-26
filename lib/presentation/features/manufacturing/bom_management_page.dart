import 'package:flutter/material.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/bom_service.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class BomManagementPage extends StatefulWidget {
  const BomManagementPage({super.key});

  @override
  State<BomManagementPage> createState() => _BomManagementPageState();
}

class _BomManagementPageState extends State<BomManagementPage> {
  List<BillOfMaterial> _allBoms = [];
  List<Product> _products = [];
  final Map<String, String> _productNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final bomService = di.sl<BomService>();
    _allBoms = await bomService.getAllBoms();
    _products = await (db.select(db.products)).get();
    for (final p in _products) {
      _productNames[p.id] = p.name;
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.localeName == 'ar'
              ? 'إدارة التصنيع'
              : 'Manufacturing Management',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddBomDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    // Group BOMs by finished product
    final grouped = <String, List<BillOfMaterial>>{};
    for (final bom in _allBoms) {
      grouped.putIfAbsent(bom.finishedProductId, () => []).add(bom);
    }

    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.localeName == 'ar'
                  ? 'لا توجد وصفات تصنيع'
                  : 'No manufacturing recipes',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final productId = grouped.keys.elementAt(index);
        final components = grouped[productId]!;
        final productName = _productNames[productId] ?? productId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(Icons.category),
            title: Text(productName),
            subtitle: Text(
              l10n.localeName == 'ar'
                  ? '${components.length} مكون'
                  : '${components.length} component(s)',
            ),
            children: components
                .map((bom) => _buildComponentTile(bom))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildComponentTile(BillOfMaterial bom) {
    final componentName =
        _productNames[bom.componentProductId] ?? bom.componentProductId;
    return ListTile(
      leading: const Icon(Icons.arrow_right, color: Colors.grey),
      title: Text(componentName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bom.quantity.toStringAsFixed(2)),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _showEditQuantityDialog(bom),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: () => _confirmDelete(bom),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBomDialog() async {
    final l10n = AppLocalizations.of(context)!;
    String? finishedProduct;
    String? component;
    final qtyCtrl = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.localeName == 'ar'
              ? 'إضافة مكون تصنيع'
              : 'Add Manufacturing Component',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: finishedProduct,
                decoration: InputDecoration(
                  labelText: l10n.localeName == 'ar'
                      ? 'المنتج المُصنَّع'
                      : 'Finished Product',
                ),
                items: _products
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (v) => finishedProduct = v,
                validator: (v) => v == null ? 'مطلوب' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: component,
                decoration: InputDecoration(
                  labelText: l10n.localeName == 'ar'
                      ? 'المادة الخام'
                      : 'Raw Material',
                ),
                items: _products
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (v) => component = v,
                validator: (v) => v == null ? 'مطلوب' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: qtyCtrl,
                decoration: InputDecoration(
                  labelText: l10n.localeName == 'ar'
                      ? 'الكمية المطلوبة'
                      : 'Required Quantity',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'مطلوب';
                  if (double.tryParse(v) == null) return 'رقم غير صالح';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.localeName == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                          final bomService = di.sl<BomService>();
                await bomService.addComponent(
                  finishedProduct!,
                  component!,
                  double.parse(qtyCtrl.text),
                );
                if (context.mounted) Navigator.pop(ctx);
                await _loadData();
              }
            },
            child: Text(l10n.localeName == 'ar' ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditQuantityDialog(BillOfMaterial bom) async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: bom.quantity.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.localeName == 'ar' ? 'تعديل الكمية' : 'Edit Quantity'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.localeName == 'ar' ? 'الكمية' : 'Quantity',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.localeName == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
                        final bomService = di.sl<BomService>();
              await bomService.updateComponentQuantity(
                bom.id,
                double.parse(ctrl.text),
              );
              if (context.mounted) Navigator.pop(ctx);
              await _loadData();
            },
            child: Text(l10n.localeName == 'ar' ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BillOfMaterial bom) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.localeName == 'ar' ? 'تأكيد الحذف' : 'Confirm Delete'),
        content: Text(
          l10n.localeName == 'ar'
              ? 'هل أنت متأكد من حذف هذا المكون؟'
              : 'Are you sure you want to delete this component?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.localeName == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.localeName == 'ar' ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final bomService = di.sl<BomService>();      await bomService.removeComponent(bom.id);
      await _loadData();
    }
  }
}

class BomAssemblyPage extends StatefulWidget {
  const BomAssemblyPage({super.key});

  @override
  State<BomAssemblyPage> createState() => _BomAssemblyPageState();
}

class _BomAssemblyPageState extends State<BomAssemblyPage> {
  List<Product> _finishedProducts = [];
  List<Warehouse> _warehouses = [];
  String? _selectedProductId;
  String? _selectedWarehouseId;
  final _quantityCtrl = TextEditingController(text: '1');
  final _batchCtrl = TextEditingController();
  DateTime? _expiryDate;
  List<BillOfMaterial> _currentBom = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    _finishedProducts = await (db.select(db.products)).get();
    _warehouses = await (db.select(db.warehouses)).get();
    setState(() {});
  }

  Future<void> _loadBom(String productId) async {
              final bomService = di.sl<BomService>();
    _currentBom = await bomService.getBomForProduct(productId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.localeName == 'ar' ? 'تنفيذ التجميع' : 'Execute Assembly',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              decoration: InputDecoration(
                labelText: l10n.localeName == 'ar'
                    ? 'المنتج المُصنَّع'
                    : 'Finished Product',
                border: const OutlineInputBorder(),
              ),
              items: _finishedProducts
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedProductId = v);
                if (v != null) _loadBom(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedWarehouseId,
              decoration: InputDecoration(
                labelText: l10n.localeName == 'ar' ? 'المستودع' : 'Warehouse',
                border: const OutlineInputBorder(),
              ),
              items: _warehouses
                  .map(
                    (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedWarehouseId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityCtrl,
              decoration: InputDecoration(
                labelText: l10n.localeName == 'ar'
                    ? 'الكمية المُنتَجة'
                    : 'Produced Quantity',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _batchCtrl,
              decoration: InputDecoration(
                labelText: l10n.localeName == 'ar'
                    ? 'رقم الدفعة (اختياري)'
                    : 'Batch Number (Optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _expiryDate = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _expiryDate == null
                    ? (l10n.localeName == 'ar'
                          ? 'اختر تاريخ الانتهاء'
                          : 'Select Expiry Date')
                    : '${l10n.localeName == 'ar' ? 'تاريخ الانتهاء' : 'Expiry'}: ${_expiryDate!.toLocal().toString().split(' ')[0]}',
              ),
            ),
            if (_currentBom.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.localeName == 'ar'
                    ? 'المكونات المطلوبة:'
                    : 'Required Components:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._currentBom.map((bom) {
                final productName = _getProductName(bom.componentProductId);
                final qty =
                    bom.quantity * (double.tryParse(_quantityCtrl.text) ?? 1.0);
                return ListTile(
                  leading: const Icon(Icons.arrow_right),
                  title: Text(productName),
                  trailing: Text(qty.toStringAsFixed(2)),
                );
              }),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _assemble,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build),
              label: Text(
                l10n.localeName == 'ar' ? 'تنفيذ التجميع' : 'Execute Assembly',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductName(String id) {
    final product = _finishedProducts.where((p) => p.id == id).firstOrNull;
    return product?.name ?? id;
  }

  Future<void> _assemble() async {
    if (_selectedProductId == null || _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.localeName == 'ar'
                ? 'يرجى اختيار المنتج والمستودع'
                : 'Please select product and warehouse',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
              final bomService = di.sl<BomService>();

    try {
      final result = await bomService.assemble(
        finishedProductId: _selectedProductId!,
        producedQuantity: double.parse(_quantityCtrl.text),
        warehouseId: _selectedWarehouseId!,
        batchNumber: _batchCtrl.text.isEmpty ? null : _batchCtrl.text,
        expiryDate: _expiryDate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.green),
        );
        setState(() {
          _quantityCtrl.text = '1';
          _batchCtrl.clear();
          _expiryDate = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
