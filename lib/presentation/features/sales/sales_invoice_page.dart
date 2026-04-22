import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/erp_data_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/presentation/features/sales/widgets/sales_item_row.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

class SalesInvoicePage extends StatefulWidget {
  const SalesInvoicePage({super.key});

  @override
  State<SalesInvoicePage> createState() => _SalesInvoicePageState();
}

class _SalesInvoicePageState extends State<SalesInvoicePage> {
  Customer? _selectedCustomer;
  CustomerSmartData? _customerSmartData;
  // ignore: unused_field
  final DateTime _selectedDate = DateTime.now();
  String _paymentType = 'cash'; // cash / credit
  final List<SalesLineItem> _items = [];
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  
  // Payment split state
  double _cashPayment = 0.0;
  double _creditPayment = 0.0;
  bool _isSplitPayment = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _total => _subtotal - _discount;

  @override
  void initState() {
    super.initState();
    _discountController.addListener(() => setState(() {}));
    _notesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerSmartData(String customerId) async {
    final data = await sl<ErpDataService>().getCustomerSmartData(customerId);
    setState(() {
      _customerSmartData = data;
    });
  }

  Future<void> _onBarcodeSubmitted(String barcode, AppDatabase db) async {
    final products = await (db.select(db.products)
          ..where((p) => p.barcode.equals(barcode) | p.sku.equals(barcode)))
        .get();

    if (products.isNotEmpty) {
      final product = products.first;
      setState(() {
        _items.add(
          SalesLineItem(
            product: product,
            quantity: 1,
            price: product.sellPrice,
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

  Future<void> _showBarcodeScanner(AppDatabase db) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _BarcodeScannerDialog(),
    );
    if (result != null && result.isNotEmpty) {
      _barcodeController.text = result;
      _onBarcodeSubmitted(result, db);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مبيعات')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(db),
                  const Divider(),
                  _buildItemsTable(db),
                  _buildAddItemButton(),
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
                child: CustomerPicker(
                  db: db,
                  value: _selectedCustomer,
                  onChanged: (value) {
                    setState(() {
                      _selectedCustomer = value;
                    });
                    if (value != null) _fetchCustomerSmartData(value.id);
                  },
                ),
              ),
              const SizedBox(width: 16),
              if (_selectedCustomer != null && _customerSmartData != null)
                _buildCustomerSmartInfo(),
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showBarcodeScanner(db),
                icon: const Icon(Icons.camera_alt),
                tooltip: 'مسح الباركود بالكاميرا',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'cash', child: Text('نقد')),
                    const DropdownMenuItem(value: 'credit', child: Text('آجل')),
                    const DropdownMenuItem(value: 'partial', child: Text('جزءي')),
                    const DropdownMenuItem(value: 'split', child: Text('مجزأ')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _paymentType = value!;
                      _isSplitPayment = (value == 'split');
                    });
                  },
                  initialValue: _paymentType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Split payment fields
          if (_isSplitPayment) _buildSplitPaymentFields(),
          const SizedBox(height: 16),
          // Notes field
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPaymentFields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'دفع نقدي',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _cashPayment = double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'دفع آجل',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _creditPayment = double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المتبقي:', style: TextStyle(color: Colors.red)),
              Text(
                (_total - _cashPayment - _creditPayment).toStringAsFixed(2),
                style: TextStyle(
                  color: _cashPayment + _creditPayment >= _total ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSmartInfo() {
    final isExceeding = (_customerSmartData!.currentBalance + _total) > _customerSmartData!.creditLimit && _customerSmartData!.creditLimit > 0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isExceeding ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الرصيد: ${_customerSmartData!.currentBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text('الحد الائتماني: ${_customerSmartData!.creditLimit.toStringAsFixed(2)}', style: TextStyle(fontSize: 10, color: isExceeding ? Colors.red : null)),
          if (isExceeding)
            const Text('تنبيه: تجاوز الحد الائتماني!', style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
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
            return SalesItemRow(
              index: index,
              item: _items[index],
              products: products,
              customerId: _selectedCustomer?.id,
              onDelete: () => setState(() => _items.removeAt(index)),
              onChanged: () => setState(() {}),
            );
          },
        );
      },
    );
  }

  Widget _buildAddItemButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _items.add(SalesLineItem())),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _summaryRow('المجموع الفرعي:', _subtotal),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الخصم الإجمالي:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
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
          const Divider(),
          _summaryRow('الإجمالي النهائي:', _total, isBold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 18 : null,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 18 : null,
            color: isBold ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(AppDatabase db) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _items.isEmpty || _isSaving ? null : () => _saveInvoice(db, post: false),
              child: const Text('حفظ كمسودة'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _items.isEmpty || _isSaving ? null : () => _showReturnDialog(context),
              icon: const Icon(Icons.assignment_return, size: 18),
              label: const Text('مرتجع'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PermissionGuard(
              permissionCode: 'sales.post',
              child: ElevatedButton(
                onPressed: _items.isEmpty || _isSaving ? null : () => _saveInvoice(db, post: true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('ترحيل'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReturnDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء مرتجع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سيتم إنشاء مرتجع بناءً على الأصناف المضافة'),
            const SizedBox(height: 16),
            Text('الإجمالي المرتجع: ${_total.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/sales/returns/new', extra: {'items': _items, 'total': _total});
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInvoice(AppDatabase db, {required bool post}) async {
    if (_items.isEmpty) return;
    
    // Check stock availability first
    for (var item in _items) {
      if (item.product != null) {
        final product = item.product!;
        if (product.stock < item.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('الكمية غير متاحة للمنتج: ${product.name} - المتوفر: ${product.stock}')),
          );
          return;
        }
      }
    }
    
    if (_paymentType == 'credit' && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب اختيار عميل للبيع الآجل')));
      return;
    }
    
    // Check credit limit for credit sales
    if ((_paymentType == 'credit' || _paymentType == 'partial') && _selectedCustomer != null && _customerSmartData != null) {
      if (_customerSmartData!.creditLimit > 0) {
        final newBalance = _customerSmartData!.currentBalance + _total;
        if (newBalance > _customerSmartData!.creditLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تجاوزت الحد الائتماني! الرصيد الحالي: ${_customerSmartData!.currentBalance} - الحد: ${_customerSmartData!.creditLimit}')),
          );
          return;
        }
      }
    }
    
    // Validate split payment
    if (_isSplitPayment) {
      if (_selectedCustomer == null && _creditPayment > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار عميل للدفع الآجل')),
        );
        return;
      }
      if ((_cashPayment + _creditPayment) < _total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المبلغ المدفوع أقل من الإجمالي')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final saleId = const Uuid().v4();
    
    // Calculate total tax based on products
    double totalTax = 0;
    for (var item in _items) {
      if (item.product != null) {
        totalTax += (item.lineTotal / (1 + (item.product!.taxRate / 100))) * (item.product!.taxRate / 100);
      }
    }

    final saleCompanion = SalesCompanion.insert(
      id: drift.Value(saleId),
      customerId: drift.Value(_selectedCustomer?.id),
      total: _total,
      tax: drift.Value(totalTax),
      discount: drift.Value(_discount),
      paymentMethod: _paymentType,
      isCredit: drift.Value(_paymentType == 'credit'),
      status: const drift.Value('DRAFT'),
    );

    final itemsCompanions = _items.map((item) => SaleItemsCompanion.insert(
      saleId: saleId,
      productId: item.product!.id,
      quantity: item.quantity,
      price: item.price,
      unitName: drift.Value(item.selectedUnit),
      unitFactor: drift.Value(item.unitFactor),
    )).toList();

    try {
      await db.salesDao.createSale(
        saleCompanion: saleCompanion,
        itemsCompanions: itemsCompanions,
        userId: null,
      );

      if (post) {
        await sl<TransactionEngine>().postSale(saleId, userId: null);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(post ? 'تم ترحيل الفاتورة' : 'تم حفظ المسودة')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

/// Dialog for scanning barcodes using the camera
class _BarcodeScannerDialog extends StatefulWidget {
  const _BarcodeScannerDialog();

  @override
  State<_BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<_BarcodeScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مسح الباركود',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_isScanned) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      setState(() => _isScanned = true);
                      Navigator.pop(context, barcodes.first.rawValue);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flash_on),
                  tooltip: 'إضاءة',
                ),
                const SizedBox(width: 32),
                IconButton(
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.cameraswitch),
                  tooltip: 'تبديل الكاميرا',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
