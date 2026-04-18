import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:uuid/uuid.dart';

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  Supplier? _selectedSupplier;
  Warehouse? _selectedWarehouse;
  DateTime _selectedDate = DateTime.now();
  String _paymentType = 'credit'; // cash / credit
  final List<_PurchaseLineItem> _items = [];
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _otherExpensesController =
      TextEditingController();
  bool _isSaving = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _shippingCost =>
      double.tryParse(_shippingCostController.text) ?? 0.0;
  double get _otherExpenses =>
      double.tryParse(_otherExpensesController.text) ?? 0.0;
  double get _total => _subtotal - _discount + _shippingCost + _otherExpenses;

  @override
  void initState() {
    super.initState();
    _ensureDefaultWarehouse();
    _discountController.addListener(() => setState(() {}));
    _shippingCostController.addListener(() => setState(() {}));
    _otherExpensesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _discountController.dispose();
    _shippingCostController.dispose();
    _otherExpensesController.dispose();
    super.dispose();
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

  Future<void> _handleSupplierSearch(String name, AppDatabase db) async {
    if (name.isEmpty) return;
    final suppliers = await db.suppliersDao.searchSuppliers(name);
    if (suppliers.isNotEmpty) {
      setState(() {
        _selectedSupplier = suppliers.first;
        _supplierController.text = suppliers.first.name;
      });
    } else {
      // إنشاء مورد جديد
      final newSupplierId = await db.suppliersDao.insertSupplierWithAccount(
        SuppliersCompanion.insert(name: name),
      );
      final createdSupplier = await db.suppliersDao.getSupplierById(
        newSupplierId,
      );
      setState(() {
        _selectedSupplier = createdSupplier;
      });
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
                child: StreamBuilder<List<Supplier>>(
                  stream: db.select(db.suppliers).watch(),
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    return DropdownButtonFormField<Supplier>(
                      decoration: const InputDecoration(
                        labelText: 'اختيار المورد',
                        border: OutlineInputBorder(),
                      ),
                      items: suppliers
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSupplier = value;
                          _supplierController.text = value?.name ?? '';
                        });
                      },
                      initialValue: _selectedSupplier,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _supplierController,
                  decoration: const InputDecoration(
                    labelText: 'إدخال مورد جديد',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _handleSupplierSearch(value, db),
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
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('لا توجد أصناف')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Product>>(
                    stream: db.select(db.products).watch(),
                    builder: (context, snapshot) {
                      final products = snapshot.data ?? [];
                      return DropdownButtonFormField<Product>(
                        decoration: const InputDecoration(labelText: 'المنتج'),
                        items: products
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              item.product = value;
                              item.selectedUnit = value.unit;
                              item.price = value.buyPrice;
                            });
                          }
                        },
                        initialValue: item.product,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'الوحدة'),
                    items: ['حبة', 'كرتون', 'كيلو', 'علبة']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        item.selectedUnit = value!;
                      });
                    },
                    initialValue: item.selectedUnit,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'الكمية'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        item.quantity = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'السعر'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        item.price = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.lineTotal.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _items.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          ),
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
      _items.add(_PurchaseLineItem());
    });
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع الفرعي:'),
              Text(_subtotal.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الخصم:'),
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
              const Text('الشحن:'),
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
              const Text('مصروفات أخرى:'),
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
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الإجمالي:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                _total.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (_items.isEmpty || _selectedWarehouse == null || _isSaving)
              ? null
              : () => _savePurchase(db),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('حفظ الفاتورة'),
        ),
      ),
    );
  }

  Future<void> _savePurchase(AppDatabase db) async {
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
      // إنشاء batches
      for (var item in _items) {
        await db
            .into(db.productBatches)
            .insert(
              ProductBatchesCompanion.insert(
                productId: item.product!.id,
                warehouseId: _selectedWarehouse!.id,
                batchNumber: 'PURCHASE-$purchaseId-${item.product!.id}',
                quantity: drift.Value(item.quantity),
                initialQuantity: drift.Value(item.quantity),
                costPrice: drift.Value(item.price),
              ),
            );
        // تحديث stock في products
        final product = await db.productsDao.getProductById(item.product!.id);
        if (product != null) {
          await db
              .update(db.products)
              .replace(product.copyWith(stock: product.stock + item.quantity));
        }
      }
      // استخدم purchase_service للـ posting
      await sl<PurchaseService>().postPurchase(purchaseId: purchaseId, userId: null);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الفاتورة')),
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

class _PurchaseLineItem {
  Product? product;
  String selectedUnit;
  double quantity;
  double price;
  double get lineTotal => quantity * price;
  _PurchaseLineItem()
      : product = null,
        selectedUnit = 'حبة',
        quantity = 0.0,
        price = 0.0;
}
