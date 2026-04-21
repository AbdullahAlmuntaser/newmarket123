import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/quick_customer_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/presentation/features/sales/sales_provider.dart';
import 'package:uuid/uuid.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  Customer? _selectedCustomer;
  DateTime _selectedDate = DateTime.now();
  String _paymentType = 'cash'; // cash / credit
  final List<_SaleLineItem> _items = [];
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  bool _isSaving = false;
  bool _autoPrint = true;
  String _invoiceNumber = '';

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _total => _subtotal - _discount;

  @override
  void initState() {
    super.initState();
    _generateInvoiceNumber();
    _discountController.addListener(() => setState(() {}));
  }

  final TextEditingController _barcodeController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    _customerController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeSubmitted(String barcode, AppDatabase db) async {
    final products = await (db.select(db.products)
          ..where((p) => p.barcode.equals(barcode) | p.sku.equals(barcode)))
        .get();

    if (products.isNotEmpty) {
      _addProductToSale(products.first);
      _barcodeController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المنتج غير موجود')),
      );
    }
  }

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final time = now.millisecondsSinceEpoch.toString().substring(8);
    _invoiceNumber = 'INV-$year$month$day-$time';
  }

  Future<void> _handleCustomerSearch(String name, AppDatabase db) async {
    if (name.isEmpty) return;
    final customer = await sl<QuickCustomerService>().getOrCreateCustomerForSale(name);
    if (customer != null) {
      setState(() {
        _selectedCustomer = customer;
        _customerController.text = customer.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final salesProvider = SalesProvider(db);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_clock),
            tooltip: 'إغلاق الوردية',
            onPressed: () => _showCloseShiftDialog(db),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHeader(db, salesProvider),
                        const Divider(),
                        _buildAlertsPanel(salesProvider),
                        const Divider(),
                        _buildItemsTable(db, salesProvider),
                        _buildAddItemButton(db, salesProvider),
                        const Divider(),
                        _buildSummary(),
                      ],
                    ),
                  ),
                ),
                _buildFooter(db),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 1,
            child: _buildQuickProductsPanel(db),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickProductsPanel(AppDatabase db) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('الأكثر مبيعاً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: db.salesDao.getMostSoldProducts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final products = snapshot.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return InkWell(
                    onTap: () => _addProductToSale(p),
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('${p.sellPrice}', style: const TextStyle(color: Colors.blue)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _addProductToSale(Product product) {
    setState(() {
      final existingIndex = _items.indexWhere((item) => item.product?.id == product.id);
      if (existingIndex != -1) {
        _items[existingIndex].quantity += 1;
      } else {
        _items.add(_SaleLineItem()
          ..product = product
          ..price = product.sellPrice
          ..quantity = 1
          ..selectedUnit = product.unit);
      }
    });
  }

  Future<void> _showCloseShiftDialog(AppDatabase db) async {
    // Logic for closing shift
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق الوردية'),
        content: const Text('هل أنت متأكد من إغلاق الوردية الحالية؟ سيتم إصدار تقرير الملخص.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/accounting/shifts');
            },
            child: const Text('تأكيد الإغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppDatabase db, SalesProvider salesProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _invoiceNumber,
                  decoration: const InputDecoration(
                    labelText: 'رقم الفاتورة',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 16),
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
                    const DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    const DropdownMenuItem(value: 'credit', child: Text('آجل')),
                  ],
                  onChanged: (value) {
                    setState(() => _paymentType = value!);
                    // Check credit limit
                    if (value == 'credit' && _selectedCustomer != null) {
                      salesProvider.checkAlerts(newSaleTotal: _total, isCredit: true);
                    }
                  },
                  initialValue: _paymentType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _barcodeController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'مسح الباركود / SKU',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                  onSubmitted: (value) => _onBarcodeSubmitted(value, db),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: 'إدخال عميل جديد (سريع)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) => _handleCustomerSearch(value, db),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<Customer>>(
                  stream: db.select(db.customers).watch(),
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? [];
                    return DropdownButtonFormField<Customer>(
                      decoration: const InputDecoration(
                        labelText: 'اختيار العميل المسجل',
                        border: OutlineInputBorder(),
                      ),
                      items: customers
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCustomer = value;
                          _customerController.text = value?.name ?? '';
                        });
                        if (value != null) salesProvider.loadCustomerData(value.id);
                      },
                      initialValue: _selectedCustomer,
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

  Widget _buildItemsTable(AppDatabase db, SalesProvider salesProvider) {
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
                              item.price = value.sellPrice;
                            });
                            // Load product smart info
                            salesProvider.loadProductData(value.id);
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

  Widget _buildAddItemButton(AppDatabase db, SalesProvider salesProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () => _addNewItem(salesProvider),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
      ),
    );
  }

  void _addNewItem(SalesProvider salesProvider) {
    setState(() {
      _items.add(_SaleLineItem());
    });
    // Check credit alerts when adding items
    if (_selectedCustomer != null && _paymentType == 'credit') {
      salesProvider.checkAlerts(newSaleTotal: _total, isCredit: true);
    }
  }

  /// Build alerts panel for sales
  Widget _buildAlertsPanel(SalesProvider salesProvider) {
    if (salesProvider.alerts.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('تنبيهات', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ...salesProvider.alerts.map((alert) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  alert.isBlocking ? Icons.block : Icons.warning_amber,
                  color: alert.isBlocking ? Colors.red : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    alert.message,
                    style: TextStyle(
                      color: alert.isBlocking ? Colors.red : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Checkbox(
                value: _autoPrint,
                onChanged: (v) => setState(() => _autoPrint = v!),
              ),
              const Text('طباعة تلقائية'),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (_items.isEmpty || (_paymentType == 'credit' && _selectedCustomer == null) || _isSaving)
                      ? null
                      : () => _completeSale(db),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إتمام البيع (F10)', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _items.isEmpty ? null : () => _printSale(),
                icon: const Icon(Icons.print),
                label: const Text('طباعة'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _completeSale(AppDatabase db) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة أصناف على الأقل')),
      );
      return;
    }
    if (_paymentType == 'credit' && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب اختيار عميل في البيع الآجل')),
      );
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
      // Check stock
      if (item.product!.stock < item.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('المخزون غير كافي للمنتج ${item.product!.name}')),
        );
        return;
      }
    }
    setState(() => _isSaving = true);
    final saleId = const Uuid().v4();
    final saleCompanion = SalesCompanion.insert(
      id: drift.Value(saleId),
      customerId: drift.Value(_selectedCustomer?.id),
      total: _total,
      discount: drift.Value(_discount),
      paymentMethod: _paymentType,
      isCredit: drift.Value(_paymentType == 'credit'),
      status: const drift.Value('COMPLETED'),
    );
    final itemsCompanions = _items
        .map(
          (item) => SaleItemsCompanion.insert(
            saleId: saleId,
            productId: item.product!.id,
            quantity: item.quantity,
            price: item.price,
            unitName: drift.Value(item.selectedUnit),
          ),
        )
        .toList();
    try {
      await db.salesDao.createSale(
        saleCompanion: saleCompanion,
        itemsCompanions: itemsCompanions,
        userId: null,
      );
      // Post sale
      await sl<TransactionEngine>().postSale(saleId, userId: null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إتمام البيع')),
        );
        
        if (_autoPrint) {
          _printSale();
        }

        // Reset for new sale
        setState(() {
          _items.clear();
          _selectedCustomer = null;
          _customerController.clear();
          _discountController.clear();
          _generateInvoiceNumber();
        });
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

  void _printSale() {
    // Implement printing using printer_helper
    // For now, just show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طباعة الفاتورة'),
        content: const Text('سيتم طباعة الفاتورة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }
}

class _SaleLineItem {
  Product? product;
  String selectedUnit;
  double quantity;
  double price;
  double get lineTotal => quantity * price;
  _SaleLineItem()
      : product = null,
        selectedUnit = 'حبة',
        quantity = 0.0,
        price = 0.0;
}
