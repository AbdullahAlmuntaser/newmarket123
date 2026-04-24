import 'package:supermarket/core/services/unit_conversion_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/erp_data_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/presentation/features/sales/widgets/sales_item_row.dart';
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
  DateTime _selectedDate = DateTime.now();
  String _paymentType = 'cash'; // cash / credit
  final List<SalesLineItem> _items = [];
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  bool _isSaving = false;
  bool _isHeaderExpanded = true;
  
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
    if (barcode.isEmpty) return;
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
        SnackBar(content: Text('المنتج $barcode غير موجود')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة مبيعات'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCollapsibleHeader(db),
                  _buildBarcodeSearch(db),
                  _buildCustomerAlerts(),
                  const Divider(),
                  _buildItemsList(db),
                  _buildAddItemButton(),
                  _buildSummarySection(),
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
      child: ExpansionTile(
        initiallyExpanded: _isHeaderExpanded,
        onExpansionChanged: (v) => setState(() => _isHeaderExpanded = v),
        title: Text(_selectedCustomer?.name ?? 'اختر العميل', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('الدفع: $_paymentType | التاريخ: ${_selectedDate.toString().split(' ')[0]}'),
        leading: const Icon(Icons.person_outline),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CustomerPicker(
                  db: db,
                  value: _selectedCustomer,
                  onChanged: (value) {
                    setState(() => _selectedCustomer = value);
                    if (value != null) _fetchCustomerSmartData(value.id);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder(), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقد')),
                          DropdownMenuItem(value: 'credit', child: Text('آجل')),
                          DropdownMenuItem(value: 'partial', child: Text('جزئي')),
                          DropdownMenuItem(value: 'split', child: Text('مجزأ')),
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
                    const SizedBox(width: 8),
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
                  ],
                ),
                if (_isSplitPayment) _buildSplitPaymentFields(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _referenceController,
                        decoration: const InputDecoration(labelText: 'رقم المرجع الخارجي', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _termsController,
                        decoration: const InputDecoration(labelText: 'شروط الدفع', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات الفاتورة', border: OutlineInputBorder(), isDense: true),
                  maxLines: 2,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                hintText: 'مسح باركود أو بحث...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () => _showBarcodeScanner(db),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
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

  Widget _buildCustomerAlerts() {
    if (_selectedCustomer == null || _customerSmartData == null) return const SizedBox.shrink();
    final isExceeding = (_customerSmartData!.currentBalance + _total) > _customerSmartData!.creditLimit && _customerSmartData!.creditLimit > 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isExceeding ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isExceeding ? Colors.red.shade200 : Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(isExceeding ? Icons.warning : Icons.info, color: isExceeding ? Colors.red : Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isExceeding 
                ? 'تنبيه: العميل تجاوز الحد الائتماني! الرصيد: ${_customerSmartData!.currentBalance.toStringAsFixed(2)}' 
                : 'رصيد العميل: ${_customerSmartData!.currentBalance.toStringAsFixed(2)} | الحد: ${_customerSmartData!.creditLimit.toStringAsFixed(2)}',
              style: TextStyle(color: isExceeding ? Colors.red.shade900 : Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(AppDatabase db) {
    if (_items.isEmpty) return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('لا توجد أصناف مضافة')));
    
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
            final item = _items[index];
            return Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.endToStart,
              background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
              onDismissed: (_) => setState(() => _items.removeAt(index)),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SalesItemRow(
                  index: index,
                  item: item,
                  products: products,
                  customerId: _selectedCustomer?.id,
                  onDelete: () => setState(() => _items.removeAt(index)),
                  onChanged: () => setState(() {}),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddItemButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextButton.icon(
        onPressed: () => setState(() => _items.add(SalesLineItem())),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('إضافة منتج يدوياً'),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withAlpha(30), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _row('المجموع الفرعي', _subtotal),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الخصم الإجمالي'),
              SizedBox(width: 80, child: TextField(controller: _discountController, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true))),
            ],
          ),
          const Divider(),
          _row('الصافي المستحق', _total, isBold: true, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _row(String label, double val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val.toStringAsFixed(2), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }

  Widget _buildSplitPaymentFields() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'كاش', isDense: true), keyboardType: TextInputType.number, onChanged: (v) => setState(() => _cashPayment = double.tryParse(v) ?? 0))),
              const SizedBox(width: 8),
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'آجل', isDense: true), keyboardType: TextInputType.number, onChanged: (v) => setState(() => _creditPayment = double.tryParse(v) ?? 0))),
            ],
          ),
          const SizedBox(height: 8),
          Text('المتبقي: ${(_total - _cashPayment - _creditPayment).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildFooter(AppDatabase db) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))]),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: _items.isEmpty || _isSaving ? null : () => _saveInvoice(db, post: false), child: const Text('مسودة'))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(onPressed: _items.isEmpty || _isSaving ? null : () => _saveInvoice(db, post: true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('ترحيل'))),
        ],
      ),
    );
  }

  // --- Utility logic same as original but with slight fixes ---
  Future<void> _showBarcodeScanner(AppDatabase db) async {
    final result = await showDialog<String>(context: context, builder: (context) => const _BarcodeScannerDialog());
    if (result != null && result.isNotEmpty) { _barcodeController.text = result; _onBarcodeSubmitted(result, db); }
  }

  Future<void> _saveInvoice(AppDatabase db, {required bool post}) async {
    if (_items.isEmpty) return;
    if (_paymentType == 'credit' && _selectedCustomer == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب اختيار عميل للبيع الآجل'))); return; }
    
    setState(() => _isSaving = true);
    final saleId = const Uuid().v4();
    double totalTax = 0;
    for (var item in _items) { if (item.product != null) totalTax += (item.lineTotal / (1 + (item.product!.taxRate / 100))) * (item.product!.taxRate / 100); }

    try {
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
      final itemsCompanions = <SaleItemsCompanion>[];
      for (var item in _items) {
        final baseQuantity = await sl<UnitConversionService>().convertToBaseUnit(
          productId: item.product!.id,
          quantity: item.quantity,
          unitName: item.selectedUnit,
        );
        itemsCompanions.add(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: item.product!.id,
            quantity: baseQuantity,
            price: item.price,
            unitName: drift.Value(item.selectedUnit),
            unitFactor: drift.Value(item.unitFactor),
          ),
        );
      }
      await db.salesDao.createSale(saleCompanion: saleCompanion, itemsCompanions: itemsCompanions, userId: null);
      if (post) await sl<TransactionEngine>().postSale(saleId, userId: null);
      if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(post ? 'تم ترحيل الفاتورة' : 'تم حفظ المسودة'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); } finally { setState(() => _isSaving = false); }
  }
}

class _BarcodeScannerDialog extends StatefulWidget {
  const _BarcodeScannerDialog();
  @override
  State<_BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<_BarcodeScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
  bool _isScanned = false;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Dialog(child: Container(width: MediaQuery.of(context).size.width * 0.9, height: MediaQuery.of(context).size.height * 0.6, padding: const EdgeInsets.all(16), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('مسح الباركود', style: Theme.of(context).textTheme.titleLarge), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]), const SizedBox(height: 16), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: MobileScanner(controller: _controller, onDetect: (capture) { if (_isScanned) return; final List<Barcode> barcodes = capture.barcodes; if (barcodes.isNotEmpty && barcodes.first.rawValue != null) { setState(() => _isScanned = true); Navigator.pop(context, barcodes.first.rawValue); } }))), const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flash_on)), const SizedBox(width: 32), IconButton(onPressed: () => _controller.switchCamera(), icon: const Icon(Icons.cameraswitch))])])));
  }
}
