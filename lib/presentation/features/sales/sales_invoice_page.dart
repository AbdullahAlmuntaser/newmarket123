import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';
import 'package:supermarket/core/services/permission_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/unit_conversion_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/erp_data_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/presentation/features/sales/widgets/sales_item_row.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:supermarket/presentation/widgets/money_form_field.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

class SalesInvoicePage extends StatefulWidget {
  final String? saleId;
  const SalesInvoicePage({super.key, this.saleId});

  @override
  State<SalesInvoicePage> createState() => _SalesInvoicePageState();
}

class _SalesInvoicePageState extends State<SalesInvoicePage> {
  Customer? _selectedCustomer;
  CustomerSmartData? _customerSmartData;
  Warehouse? _selectedWarehouse;
  final DateTime _selectedDate = DateTime.now();
  String _paymentType = 'cash'; // cash / credit
  String? _representativeId;
  String _priceLevel = 'RETAIL';
  final List<SalesLineItem> _items = [];
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _otherExpensesController =
      TextEditingController();
  bool _isSaving = false;
  Sale? _loadedSale;
  final _currencyFormatter = NumberFormat.currency(locale: 'ar', symbol: '');
  double _originalTax = 0.0;
  bool _isHeaderExpanded = true;

  bool get _isLockedForEditing =>
      isEditMode &&
      _loadedSale != null &&
      _loadedSale!.status != DocumentStatus.draft;

  double _cashPayment = 0.0;
  double _creditPayment = 0.0;
  bool _isSplitPayment = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double _moneyValue(TextEditingController controller) =>
      MoneyFormField.valueOf(controller);

  double get _discount => _moneyValue(_discountController);
  double get _shippingCost => _moneyValue(_shippingCostController);
  double get _otherExpenses => _moneyValue(_otherExpensesController);
  double get _tax => _moneyValue(_taxController);

  double get _totalTax => _tax;

  double get _total =>
      _subtotal + _totalTax - _discount + _shippingCost + _otherExpenses;

  bool get isEditMode => widget.saleId != null;

  @override
  void initState() {
    super.initState();
    _discountController.addListener(() => setState(() {}));
    _taxController.addListener(() => setState(() {}));
    _shippingCostController.addListener(() => setState(() {}));
    _otherExpensesController.addListener(() => setState(() {}));
    if (isEditMode) {
      _loadSaleData();
    }
  }

  Future<void> _loadSaleData() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final sale = await (db.select(db.sales)
          ..where((s) => s.id.equals(widget.saleId!)))
        .getSingleOrNull();
    if (sale != null && mounted) {
      final items = await (db.select(db.saleItems)
            ..where((i) => i.saleId.equals(widget.saleId!)))
          .get();

      Customer? customer;
      if (sale.customerId != null) {
        customer = await (db.select(db.customers)
              ..where((c) => c.id.equals(sale.customerId!)))
            .getSingleOrNull();
      }

      Warehouse? warehouse;
      if (sale.warehouseId != null) {
        warehouse = await (db.select(db.warehouses)
              ..where((w) => w.id.equals(sale.warehouseId!)))
            .getSingleOrNull();
      }

      List<Product> products = [];
      for (var item in items) {
        final product = await (db.select(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .getSingleOrNull();
        if (product != null) products.add(product);
      }

      setState(() {
        _loadedSale = sale;
        _discountController.text = sale.discount.toString();
        _shippingCostController.text = sale.shippingCost.toString();
        _otherExpensesController.text = sale.otherExpenses.toString();
        _originalTax = sale.tax;
        _taxController.text = sale.tax == 0 ? '' : sale.tax.toString();
        _selectedCustomer = customer;
        _selectedWarehouse = warehouse;
        _paymentType = sale.isCredit
            ? 'credit'
            : (sale.paymentMethod == PaymentMethod.bank ? 'bank' : 'cash');

        for (int i = 0; i < items.length && i < products.length; i++) {
          _items.add(SalesLineItem(
            product: products[i],
            quantity: items[i].quantity,
            price: items[i].price,
            selectedUnit: items[i].unitName,
          ));
        }
      });
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _taxController.dispose();
    _shippingCostController.dispose();
    _otherExpensesController.dispose();
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
    if (_isLockedForEditing) {
      AppSnackBar.warning(
        context,
        'لا يمكن إضافة أصناف إلى فاتورة مبيعات غير مسودة',
      );
      return;
    }

    // 1. Search in main products table
    final products = await (db.select(
      db.products,
    )..where((p) => p.barcode.equals(barcode) | p.sku.equals(barcode)))
        .get();

    if (products.isNotEmpty) {
      final product = products.first;
      _addItemToInvoice(product, 1, product.sellPrice, product.unit);
      _barcodeController.clear();
      return;
    }

    // 2. Search in product units table (multi-unit support)
    final unitQuery = await (db.select(db.productUnits).join([
      drift.innerJoin(
          db.products, db.products.id.equalsExp(db.productUnits.productId)),
    ])
          ..where(db.productUnits.barcode.equals(barcode)))
        .get();

    if (unitQuery.isNotEmpty) {
      final row = unitQuery.first;
      final product = row.readTable(db.products);
      final unit = row.readTable(db.productUnits);
      _addItemToInvoice(
          product, 1, unit.sellPrice ?? product.sellPrice, unit.unitName);
      _barcodeController.clear();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('المنتج $barcode غير موجود')));
  }

  void _addItemToInvoice(
      Product product, double qty, double price, String unit) {
    if (_isLockedForEditing) {
      AppSnackBar.warning(
        context,
        'لا يمكن إضافة أصناف إلى فاتورة مبيعات غير مسودة',
      );
      return;
    }
    setState(() {
      _items.add(
        SalesLineItem(
          product: product,
          quantity: qty,
          price: price,
          selectedUnit: unit,
        ),
      );
    });
  }

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(isEditMode ? 'تعديل فاتورة مبيعات' : 'فاتورة مبيعات'),
          elevation: 0),
      body: Form(
        key: _formKey, // ربط النموذج للتحقق
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_isLockedForEditing) _buildLockedBanner(),
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
      ),
    );
  }


  Widget _buildLockedBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'هذه الفاتورة ليست مسودة، لذلك لا يمكن تعديلها مباشرة. استخدم مرتجعاً أو مستند تصحيح عند الحاجة.',
              ),
            ),
          ],
        ),
      );

  Widget _buildCollapsibleHeader(AppDatabase db) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        initiallyExpanded: _isHeaderExpanded,
        onExpansionChanged: (v) => setState(() => _isHeaderExpanded = v),
        title: Text(
          _selectedCustomer?.name ?? 'اختر العميل',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'الدفع: $_paymentType | التاريخ: ${_selectedDate.toString().split(' ')[0]}',
        ),
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
                WarehousePicker(
                  db: db,
                  value: _selectedWarehouse,
                  onChanged: (value) =>
                      setState(() => _selectedWarehouse = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقد')),
                          DropdownMenuItem(value: 'credit', child: Text('آجل')),
                          DropdownMenuItem(
                              value: 'partial', child: Text('جزئي')),
                          DropdownMenuItem(value: 'split', child: Text('مجزأ')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _paymentType = value!;
                            _isSplitPayment = (value == 'split');
                          });
                        },
                        value: _paymentType,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'مستوى التسعير',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const ['RETAIL', 'WHOLESALE', 'SPECIAL']
                            .map((l) =>
                                DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _priceLevel = value!),
                        value: _priceLevel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'المندوب',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('مندوب عام'))
                  ],
                  onChanged: (value) =>
                      setState(() => _representativeId = value),
                  value: _representativeId,
                ),
                if (_isSplitPayment) _buildSplitPaymentFields(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _referenceController,
                        decoration: const InputDecoration(
                          labelText: 'رقم المرجع الخارجي',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _termsController,
                        decoration: const InputDecoration(
                          labelText: 'شروط الدفع',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الفاتورة',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
    if (_selectedCustomer == null || _customerSmartData == null) {
      return const SizedBox.shrink();
    }
    final isExceeding = (_customerSmartData!.currentBalance + _total) >
            _customerSmartData!.creditLimit &&
        _customerSmartData!.creditLimit > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isExceeding ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExceeding ? Colors.red.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExceeding ? Icons.warning : Icons.info,
            color: isExceeding ? Colors.red : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isExceeding
                  ? 'تنبيه: العميل تجاوز الحد الائتماني! الرصيد: ${_customerSmartData!.currentBalance.toStringAsFixed(2)}'
                  : 'رصيد العميل: ${_customerSmartData!.currentBalance.toStringAsFixed(2)} | الحد: ${_customerSmartData!.creditLimit.toStringAsFixed(2)}',
              style: TextStyle(
                color: isExceeding ? Colors.red.shade900 : Colors.blue.shade900,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(AppDatabase db) {
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Text('لا توجد أصناف مضافة')),
      );
    }

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
              direction: _isLockedForEditing
                  ? DismissDirection.none
                  : DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => setState(() => _items.removeAt(index)),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SalesItemRow(
                  index: index,
                  item: item,
                  products: products,
                  customerId: _selectedCustomer?.id,
                  onDelete: _isLockedForEditing
                      ? () => AppSnackBar.warning(
                            context,
                            'لا يمكن حذف أصناف من فاتورة مبيعات غير مسودة',
                          )
                      : () => setState(() => _items.removeAt(index)),
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
        onPressed: _isLockedForEditing
            ? null
            : () => setState(() => _items.add(SalesLineItem())),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('إضافة منتج يدوياً'),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _row('المجموع الفرعي', _subtotal),
          _buildTaxEditableRow(),
          _editableRow('الخصم', _discountController),
          _editableRow('الشحن', _shippingCostController),
          _editableRow('مصاريف أخرى', _otherExpensesController),
          const Divider(),
          _row(
            'الصافي المستحق',
            _total,
            isBold: true,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _editableRow(String label, TextEditingController controller,
      {bool enabled = true, String? helperText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(label),
          ),
          SizedBox(
            width: 160,
            child: MoneyFormField(
              controller: controller,
              label: label,
              enabled: enabled,
              helperText: helperText,
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                helperText: helperText,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxEditableRow() {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return _editableRow('الضريبة', _taxController, enabled: false);
    }

    return FutureBuilder<bool>(
      future: sl<PermissionService>()
          .hasPermission(currentUser.id, PermissionCode.editTax),
      builder: (context, snapshot) {
        final canEditTax = snapshot.data == true;
        return _editableRow(
          'الضريبة',
          _taxController,
          enabled: canEditTax,
          helperText: canEditTax ? 'اختياري' : 'تحتاج صلاحية تعديل الضريبة',
        );
      },
    );
  }

  Widget _row(String label, double val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            _currencyFormatter.format(val),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPaymentFields() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: MoneyFormField(
                  label: 'كاش',
                  decoration: const InputDecoration(
                    labelText: 'كاش',
                    isDense: true,
                  ),
                  onValidChanged: (value) =>
                      setState(() => _cashPayment = value),
                  onChanged: (value) {
                    if (value.trim().isEmpty) setState(() => _cashPayment = 0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MoneyFormField(
                  label: 'آجل',
                  decoration: const InputDecoration(
                    labelText: 'آجل',
                    isDense: true,
                  ),
                  onValidChanged: (value) =>
                      setState(() => _creditPayment = value),
                  onChanged: (value) {
                    if (value.trim().isEmpty) setState(() => _creditPayment = 0);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'المتبقي: ${(_total - _cashPayment - _creditPayment).toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppDatabase db) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _items.isEmpty || _isSaving || _isLockedForEditing
                  ? null
                  : () => _saveInvoice(db, post: false),
              child: const Text('مسودة'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PermissionGuard(
              permission: 'POST_INVOICE',
              fallback: const SizedBox.shrink(),
              child: ElevatedButton(
                onPressed: _items.isEmpty || _isSaving || _isLockedForEditing
                    ? null
                    : () => _saveInvoice(db, post: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ترحيل'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Utility logic same as original but with slight fixes ---
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

  Future<void> _saveInvoice(AppDatabase db, {required bool post}) async {
    final currentUser =
        Provider.of<AuthProvider>(context, listen: false).currentUser;

    if (_isLockedForEditing) {
      AppSnackBar.warning(
        context,
        'لا يمكن تعديل فاتورة مبيعات غير مسودة. استخدم مرتجعاً أو مستند تصحيح بدلاً من التعديل المباشر.',
      );
      return;
    }

    final taxChanged = (_tax - _originalTax).abs() > 0.0001;
    if (taxChanged &&
        (currentUser == null ||
            !await sl<PermissionService>()
                .hasPermission(currentUser.id, PermissionCode.editTax))) {
      if (!context.mounted) return;
      AppSnackBar.error(context, 'ليست لديك صلاحية إدخال أو تعديل الضريبة');
      return;
    }

    if (_items.isEmpty) {
      if (!context.mounted) return;
      AppSnackBar.warning(context, 'الفاتورة فارغة - الرجاء إضافة أصناف');
      return;
    }

    for (var item in _items) {
      if (item.product == null) {
        if (!context.mounted) return;
        AppSnackBar.warning(context, 'الرجاء اختيار منتج لكل صنف');
        return;
      }
      if (item.quantity <= 0) {
        if (!context.mounted) return;
        AppSnackBar.warning(context, 'الكمية يجب أن تكون أكبر من صفر');
        return;
      }
      if (item.price < 0) {
        if (!context.mounted) return;
        AppSnackBar.warning(context, 'السعر يجب أن يكون أكبر من أو يساوي صفر');
        return;
      }
    }

    if (!_formKey.currentState!.validate()) {
      if (!context.mounted) return;
      AppSnackBar.warning(context, 'يرجى تصحيح الحقول المالية قبل الحفظ');
      return;
    }

    if (_paymentType == 'credit' && _selectedCustomer == null) {
      if (!context.mounted) return;
      AppSnackBar.warning(context, 'يجب اختيار عميل للبيع الآجل');
      return;
    }

    // التحقق من الحد الائتماني للعميل ومنع الحفظ عند التجاوز
    if (_paymentType == 'credit' &&
        _selectedCustomer != null &&
        _customerSmartData != null) {
      final newBalance = _customerSmartData!.currentBalance + _total;
      if (newBalance > _customerSmartData!.creditLimit &&
          _customerSmartData!.creditLimit > 0) {
        if (!context.mounted) return;
        AppSnackBar.error(
          context,
          'لا يمكن حفظ الفاتورة: العميل تجاوز الحد الائتماني المسموح به',
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final String saleId;
    final bool isNew = !isEditMode;
    saleId = isNew ? const Uuid().v4() : widget.saleId!;

    try {
      await db.transaction(() async {
        double totalItemDiscount = 0;
        for (var item in _items) {
          totalItemDiscount += item.discount;
        }

        PaymentMethod method = PaymentMethod.cash;
        if (_paymentType == 'bank') {
          method = PaymentMethod.bank;
        } else if (_paymentType == 'check') {
          method = PaymentMethod.check;
        }

        final userId = currentUser?.id;

        final itemsCompanions = <SaleItemsCompanion>[];
        for (var item in _items) {
          final baseQuantity =
              await sl<UnitConversionService>().convertToBaseUnit(
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
              costCenterId: drift.Value(item.costCenterId),
            ),
          );
        }

        if (isNew) {
          final saleCompanion = SalesCompanion.insert(
            id: drift.Value(saleId),
            customerId: drift.Value(_selectedCustomer?.id),
            total: _total,
            tax: drift.Value(_totalTax),
            discount: drift.Value(_discount + totalItemDiscount),
            paymentMethod: method,
            isCredit: drift.Value(_paymentType == 'credit'),
            status: const drift.Value(DocumentStatus.draft),
            shippingCost: drift.Value(_shippingCost),
            otherExpenses: drift.Value(_otherExpenses),
            warehouseId: drift.Value(_selectedWarehouse?.id),
            representativeId: drift.Value(_representativeId),
          );

          await db.salesDao.createSale(
            saleCompanion: saleCompanion,
            itemsCompanions: itemsCompanions,
            userId: userId,
          );

          await sl<AuditService>().logCreate(
            'SalesInvoice',
            saleId,
            details: 'فاتورة مبيعات جديدة بقيمة ${_total.toStringAsFixed(2)}',
            userId: userId,
          );
        } else {
          final saleCompanion = SalesCompanion(
            customerId: drift.Value(_selectedCustomer?.id),
            total: drift.Value(_total),
            tax: drift.Value(_totalTax),
            discount: drift.Value(_discount + totalItemDiscount),
            paymentMethod: drift.Value(method),
            isCredit: drift.Value(_paymentType == 'credit'),
            shippingCost: drift.Value(_shippingCost),
            otherExpenses: drift.Value(_otherExpenses),
            warehouseId: drift.Value(_selectedWarehouse?.id),
            representativeId: drift.Value(_representativeId),
          );

          await db.salesDao.updateSale(
            saleId: saleId,
            saleCompanion: saleCompanion,
            itemsCompanions: itemsCompanions,
            userId: userId,
          );

          await sl<AuditService>().logUpdate(
            'SalesInvoice',
            saleId,
            details: 'تم تعديل الفاتورة بقيمة ${_total.toStringAsFixed(2)}',
            userId: userId,
          );
        }

        if (post) {
          await sl<TransactionEngine>().postSale(saleId, userId: userId);
          await sl<AuditService>().logUpdate(
            'SalesInvoice',
            saleId,
            details: 'تم ترحيل الفاتورة',
            userId: userId,
          );
        }
      });

      if (!mounted) return;
      AppSnackBar.success(
        context,
        post ? 'تم ترحيل الفاتورة بنجاح' : 'تم حفظ المسودة',
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'فشل الحفظ: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

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
                    if (barcodes.isNotEmpty &&
                        barcodes.first.rawValue != null) {
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
                ),
                const SizedBox(width: 32),
                IconButton(
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.cameraswitch),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
