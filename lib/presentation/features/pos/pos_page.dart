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
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/shift_service.dart';
import 'package:supermarket/core/utils/printer_helper.dart';
import 'package:supermarket/presentation/features/pos/widgets/barcode_scanner_dialog.dart';

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
  final TextEditingController _barcodeController = TextEditingController();
  bool _isSaving = false;
  bool _autoPrint = true;
  String _invoiceNumber = '';
  bool _isHeaderExpanded = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _total => _subtotal - _discount;

  @override
  void initState() {
    super.initState();
    _generateInvoiceNumber();
    _discountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _customerController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final time = now.millisecondsSinceEpoch.toString().substring(8);
    _invoiceNumber = 'INV-$year$month$day-$time';
  }

  Future<void> _onBarcodeSubmitted(String barcode, AppDatabase db) async {
    if (barcode.isEmpty) return;
    final products = await (db.select(db.products)
          ..where((p) => p.barcode.equals(barcode) | p.sku.equals(barcode)))
        .get();

    if (products.isNotEmpty) {
      _addProductToSale(products.first);
      _barcodeController.clear();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('المنتج $barcode غير موجود')),
      );
    }
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

  Future<void> _openScanner(AppDatabase db) async {
    final result = await showGeneralDialog<String>(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) => const BarcodeScannerDialog(),
    );
    if (result != null && mounted) {
      _onBarcodeSubmitted(result, db);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    // Note: SalesProvider might need to be initialized differently if it's a ChangeNotifier
    // For now keeping the logic from original file
    final salesProvider = SalesProvider(db);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_clock),
            tooltip: 'إغلاق الوردية',
            onPressed: () => _showCloseShiftDialog(db),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Landscape / Desktop
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildMainContent(db, salesProvider),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 1,
                  child: _buildQuickProductsPanel(db),
                ),
              ],
            );
          } else {
            // Mobile Portrait
            return _buildMainContent(db, salesProvider);
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openScanner(db),
        label: const Text('مسح'),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _buildPersistentFooter(db),
    );
  }

  Widget _buildMainContent(AppDatabase db, SalesProvider salesProvider) {
    return Column(
      children: [
        _buildCompressedHeader(db, salesProvider),
        _buildBarcodeSection(db),
        _buildAlertsPanel(salesProvider),
        Expanded(
          child: _buildItemsList(db),
        ),
      ],
    );
  }

  Widget _buildCompressedHeader(AppDatabase db, SalesProvider salesProvider) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        key: GlobalKey(), // Force rebuild to update state if needed
        initiallyExpanded: _isHeaderExpanded,
        onExpansionChanged: (value) => setState(() => _isHeaderExpanded = value),
        title: Text(
          _selectedCustomer?.name ?? 'عميل عام',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'الفاتورة: ${_invoiceNumber.split('-').last} | ${_paymentType == 'cash' ? 'نقدي' : 'آجل'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        leading: Icon(
          _paymentType == 'cash' ? Icons.money : Icons.credit_card,
          color: Theme.of(context).colorScheme.primary,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
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
                            isDense: true,
                          ),
                          child: Text(_selectedDate.toString().split(' ')[0]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'نوع الدفع',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                          DropdownMenuItem(value: 'credit', child: Text('آجل')),
                        ],
                        onChanged: (value) {
                          setState(() => _paymentType = value!);
                          if (value == 'credit' && _selectedCustomer != null) {
                            salesProvider.checkAlerts(newSaleTotal: _total, isCredit: true);
                          }
                        },
                        initialValue: _paymentType,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Customer>>(
                  stream: db.select(db.customers).watch(),
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? [];
                    return DropdownButtonFormField<Customer>(
                      decoration: const InputDecoration(
                        labelText: 'اختيار العميل',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: customers
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
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
                const SizedBox(height: 8),
                TextField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: 'أو أضف عميل جديد سريع',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) => _handleCustomerSearch(value, db),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeSection(AppDatabase db) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                hintText: 'امسح الباركود أو ابحث عن منتج...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 30),
                  onPressed: () => _openScanner(db),
                  color: Theme.of(context).colorScheme.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onSubmitted: (value) => _onBarcodeSubmitted(value, db),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(AppDatabase db) {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('سلة المبيعات فارغة', style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100), // Space for footer
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Dismissible(
          key: Key(item.product?.id ?? index.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            setState(() => _items.removeAt(index));
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          item.product?.name.substring(0, 1) ?? '?',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product?.name ?? 'منتج غير محدد',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'السعر: ${item.price.toStringAsFixed(2)} | الوحدة: ${item.selectedUnit}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item.lineTotal.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildQtyButton(Icons.remove, () {
                            setState(() {
                              if (item.quantity > 1) {
                                item.quantity -= 1;
                              } else {
                                _items.removeAt(index);
                              }
                            });
                          }),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              item.quantity.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          _buildQtyButton(Icons.add, () {
                            setState(() => item.quantity += 1);
                          }),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _editItemDialog(item),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('تعديل'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  Widget _buildPersistentFooter(AppDatabase db) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المجموع الإجمالي', style: TextStyle(color: Colors.grey)),
                  Text(
                    '${_total.toStringAsFixed(2)} ر.س',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Text('طباعة', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: _autoPrint,
                        onChanged: (v) => setState(() => _autoPrint = v),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_items.isEmpty || (_paymentType == 'credit' && _selectedCustomer == null) || _isSaving)
                      ? null
                      : () => _completeSale(db),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'إتمام البيع',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _items.isEmpty ? null : () => _printSale(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.print, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Reuse logic from original file but adapted
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

  void _editItemDialog(_SaleLineItem item) {
    final priceController = TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل: ${item.product?.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'الكمية'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'السعر'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.quantity = double.tryParse(qtyController.text) ?? item.quantity;
                item.price = double.tryParse(priceController.text) ?? item.price;
              });
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
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
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return InkWell(
                    onTap: () => _addProductToSale(p),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag, color: Colors.blue, size: 30),
                            const SizedBox(height: 8),
                            Text(
                              p.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text('${p.sellPrice}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
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

  Widget _buildAlertsPanel(SalesProvider salesProvider) {
    if (salesProvider.alerts.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: salesProvider.alerts.map((a) => Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(a.message, style: TextStyle(color: Colors.red.shade900, fontSize: 12))),
          ],
        )).toList(),
      ),
    );
  }

  // --- Logic methods remain mostly same but integrated ---
  Future<void> _showCloseShiftDialog(AppDatabase db) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    final shiftService = ShiftService(db);
    final activeShift = await shiftService.getActiveShift(userId);
    if (activeShift == null) return;
    final expectedCash = await shiftService.calculateExpectedCash(activeShift);
    final cashController = TextEditingController(text: expectedCash.toStringAsFixed(2));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق الوردية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المتوقع: ${expectedCash.toStringAsFixed(2)}'),
            TextField(controller: cashController, keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await shiftService.closeShift(activeShift.id, double.tryParse(cashController.text) ?? 0.0);
              if (context.mounted) { Navigator.pop(context); context.go('/accounting/shifts'); }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSale(AppDatabase db) async {
    // Validation same as original
    if (_items.isEmpty) return;
    setState(() => _isSaving = true);
    final saleId = const Uuid().v4();
    try {
      final saleCompanion = SalesCompanion.insert(
        id: drift.Value(saleId),
        customerId: drift.Value(_selectedCustomer?.id),
        total: _total,
        discount: drift.Value(_discount),
        paymentMethod: _paymentType,
        isCredit: drift.Value(_paymentType == 'credit'),
        status: const drift.Value('COMPLETED'),
      );
      final itemsCompanions = _items.map((item) => SaleItemsCompanion.insert(
        saleId: saleId, productId: item.product!.id, quantity: item.quantity,
        price: item.price, unitName: drift.Value(item.selectedUnit),
      )).toList();
      await db.salesDao.createSale(saleCompanion: saleCompanion, itemsCompanions: itemsCompanions, userId: null);
      await sl<TransactionEngine>().postSale(saleId, userId: null);
      if (mounted) {
        if (_autoPrint) _printSale();
        setState(() { _items.clear(); _selectedCustomer = null; _generateInvoiceNumber(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إتمام البيع بنجاح')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _printSale() async {
    // Printing logic same as original
    final db = Provider.of<AppDatabase>(context, listen: false);
    final products = await (db.select(db.products)).get();
    final tempSale = Sale(
      id: 'TEMP', total: _total, discount: _discount, tax: 0.0,
      paymentMethod: _paymentType, isCredit: _paymentType == 'credit',
      status: 'POSTED', exchangeRate: 1.0, createdAt: DateTime.now(), updatedAt: DateTime.now(), syncStatus: 1,
    );
    final tempItems = _items.map((item) => SaleItem(
      id: 'TEMP', saleId: 'TEMP', productId: item.product?.id ?? '',
      quantity: item.quantity, price: item.price, unitName: item.selectedUnit,
      createdAt: DateTime.now(), updatedAt: DateTime.now(), syncStatus: 1, unitFactor: 1.0,
    )).toList();
    await PrinterHelper.printReceipt(tempSale, tempItems, products, customerName: _selectedCustomer?.name);
  }
}

class _SaleLineItem {
  Product? product;
  String selectedUnit;
  double quantity;
  double price;
  double get lineTotal => quantity * price;
  _SaleLineItem() : product = null, selectedUnit = 'حبة', quantity = 0.0, price = 0.0;
}
