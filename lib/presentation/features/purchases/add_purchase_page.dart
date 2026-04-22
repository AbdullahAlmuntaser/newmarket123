import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';
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

  Future<void> _showLoadPODialog(AppDatabase db) async {
    final pos = await (db.select(db.purchaseOrders)
          ..where((t) => t.status.equals('APPROVED'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();

    if (!mounted) return;

    if (pos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد أوامر شراء معتمدة')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختيار أمر شراء'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pos.length,
            itemBuilder: (context, index) {
              final po = pos[index];
              return ListTile(
                title: Text('أمر رقم: ${po.orderNumber ?? po.id.substring(0, 8)}'),
                subtitle: Text('التاريخ: ${po.date.toString().split(' ')[0]} - الإجمالي: ${po.total}'),
                onTap: () {
                  Navigator.pop(context);
                  _loadPOItems(po, db);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadPOItems(PurchaseOrder po, AppDatabase db) async {
    final poItems = await db.purchasesDao.getPurchaseOrderItems(po.id);
    final products = await db.select(db.products).get();

    setState(() {
      _items.clear();
      for (var pi in poItems) {
        final product = products.firstWhere((p) => p.id == pi.productId);
        _items.add(
          PurchaseLineItem(
            product: product,
            quantity: pi.quantity,
            price: pi.price,
            selectedUnit: pi.unitId ?? product.unit,
          ),
        );
      }
      if (po.supplierId != null) {
        _selectedSupplier = null; // Reset to trigger search or selection
        db.suppliersDao.getSupplierById(po.supplierId!).then((s) {
          if (s != null) {
            setState(() {
              _selectedSupplier = s;
              _supplierController.text = s.name;
            });
            _fetchSupplierSmartData(s.id);
          }
        });
      }
    });
  }

  Future<void> _ensureDefaultWarehouse() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final warehouses = await db.select(db.warehouses).get();
    if (warehouses.isEmpty) {
      final id = const Uuid().v4();
      await db
          .into(db.warehouses)
          .insert(
            WarehousesCompanion.insert(
              id: drift.Value(id),
              name: 'Main Warehouse',
              isDefault: const drift.Value(true),
            ),
          );
      final updated = await db.select(db.warehouses).get();
      setState(() => _selectedWarehouse = updated.first);
    } else {
      setState(
        () => _selectedWarehouse = warehouses.firstWhere(
          (w) => w.isDefault,
          orElse: () => warehouses.first,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مشتريات')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(db),
                  const Divider(),
                  _buildItemsTable(db),
                  _buildAddItemButton(db),
                  const Divider(),
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

  Widget _buildHeader(AppDatabase db) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SupplierPicker(
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
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showLoadPODialog(db),
                icon: const Icon(Icons.download),
                label: const Text('تحميل أمر شراء'),
              ),
              const SizedBox(width: 16),
              if (_selectedSupplier != null && _supplierSmartData != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('رصيد المورد', style: TextStyle(fontSize: 10)),
                      Text(
                        _supplierSmartData!.currentBalance.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'بحث بالباركود / SKU',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                  onSubmitted: (value) => _onBarcodeSubmitted(value, db),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'التاريخ',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_selectedDate.toString().split(' ')[0]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'نوع الدفع',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'cash', child: Text('نقد')),
                    const DropdownMenuItem(value: 'credit', child: Text('آجل')),
                  ],
                  onChanged: (value) {
                    setState(() => _paymentType = value!);
                  },
                  initialValue: _paymentType,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<List<Warehouse>>(
                  stream: db.select(db.warehouses).watch(),
                  builder: (context, snapshot) {
                    final warehouses = snapshot.data ?? [];
                    return DropdownButtonFormField<Warehouse>(
                      decoration: const InputDecoration(
                        labelText: 'المستودع',
                        border: OutlineInputBorder(),
                      ),
                      items: warehouses
                          .map(
                            (w) =>
                                DropdownMenuItem(value: w, child: Text(w.name)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedWarehouse = value);
                      },
                      initialValue: _selectedWarehouse,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(AppDatabase db) {
    return FutureBuilder<List<Product>>(
      future: db.select(db.products).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final products = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            return PurchaseItemRow(
              index: index,
              item: _items[index],
              products: products,
              supplierId: _selectedSupplier?.id,
              onDelete: () => setState(() => _items.removeAt(index)),
              onChanged: () => setState(() {}),
            );
          },
        );
      },
    );
  }

  Widget _buildAddItemButton(AppDatabase db) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () => _addNewItem(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
      ),
    );
  }

  void _addNewItem() {
    setState(() {
      _items.add(PurchaseLineItem());
    });
  }

  Widget _buildSummary() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المجموع الفرعي:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                _subtotal.toStringAsFixed(2),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الخصم:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الشحن:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _shippingCostController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مصروفات أخرى:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _otherExpensesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'جمارك:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _customsDutyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإجمالي:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                _total.toStringAsFixed(2),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppDatabase db) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (_items.isEmpty || _isSaving)
                  ? null
                  : () => _savePurchase(db, post: false),
              child: const Text('حفظ كمسودة'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PermissionGuard(
              permissionCode: 'purchases.post',
              child: ElevatedButton(
                onPressed:
                    (_items.isEmpty || _selectedWarehouse == null || _isSaving)
                        ? null
                        : () => _savePurchase(db, post: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ترحيل الفاتورة'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePurchase(AppDatabase db, {required bool post}) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة أصناف على الأقل')),
      );
      return;
    }
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب اختيار مورد')));
      return;
    }
    if (_selectedWarehouse == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب اختيار مستودع')));
      return;
    }
    for (var item in _items) {
      if (item.product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار منتج لكل صنف')),
        );
        return;
      }
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الكمية يجب أن تكون أكبر من صفر')),
        );
        return;
      }
    }
    setState(() => _isSaving = true);
    final purchaseId = const Uuid().v4();
    final purchaseCompanion = PurchasesCompanion.insert(
      id: drift.Value(purchaseId),
      supplierId: drift.Value(_selectedSupplier!.id),
      total: _total,
      discount: drift.Value(_discount),
      shippingCost: drift.Value(_shippingCost),
      otherExpenses: drift.Value(_otherExpenses),
      purchaseType: drift.Value(_paymentType),
      date: drift.Value(_selectedDate),
      isCredit: drift.Value(_paymentType == 'credit'),
      status: const drift.Value('DRAFT'),
      warehouseId: drift.Value(_selectedWarehouse!.id),
    );
    final itemsCompanions = _items
        .map(
          (item) => PurchaseItemsCompanion.insert(
            purchaseId: purchaseId,
            productId: item.product!.id,
            unitId: drift.Value(item.selectedUnit),
            quantity: item.quantity,
            unitPrice: item.price,
            price: item.lineTotal,
          ),
        )
        .toList();
    try {
      await db.purchasesDao.createPurchase(
        purchaseCompanion: purchaseCompanion,
        itemsCompanions: itemsCompanions,
        userId: null,
      );

      if (post) {
        // استخدم purchase_service للـ posting
        await sl<PurchaseService>().postPurchase(
          purchaseId: purchaseId,
          userId: null,
        );
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(post ? 'تم ترحيل الفاتورة' : 'تم حفظ المسودة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

// Remove old _PurchaseLineItem class as it's replaced by PurchaseLineItem in widgets/purchase_item_row.dart

