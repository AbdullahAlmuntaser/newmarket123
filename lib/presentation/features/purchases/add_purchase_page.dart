import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/permission_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:uuid/uuid.dart';
import 'purchase_provider.dart';
import '../../widgets/entity_picker.dart';
import '../../widgets/app_snack_bar.dart';
import 'widgets/purchase_item_row.dart';
import 'widgets/quick_product_add_dialog.dart';

import 'package:supermarket/core/services/grn_service.dart';

class AddPurchasePage extends StatefulWidget {
  final String? purchaseId;
  const AddPurchasePage({super.key, this.purchaseId});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  Supplier? _selectedSupplier;
  Warehouse? _selectedWarehouse;
  String _paymentMethod = 'cash';
  String? _selectedCurrency;
  String? _representativeId;

  final _formKey = GlobalKey<FormState>();
  final _currencyFormatter = NumberFormat.currency(locale: 'ar', symbol: '');
  DateTime _selectedDate = DateTime.now();
  final List<PurchaseItemData> _items = [];

  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _otherExpensesController =
      TextEditingController();
  final TextEditingController _taxController = TextEditingController();

  bool _isSaving = false;
  double _originalTax = 0.0;
  Purchase? _loadedPurchase;

  bool get _isLockedForEditing =>
      isEditMode &&
      _loadedPurchase != null &&
      _loadedPurchase!.status != DocumentStatus.draft;

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + (item.subtotal));
  double _moneyValue(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }
  double get _discount => _moneyValue(_discountController);
  double get _shippingCost => _moneyValue(_shippingCostController);
  double get _otherExpenses => _moneyValue(_otherExpensesController);
  double get _tax => _moneyValue(_taxController);
  double get _total =>
      _subtotal - _discount + _shippingCost + _otherExpenses + _tax;

  bool get isEditMode => widget.purchaseId != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _loadPurchaseData();
    }
  }

  Future<void> _loadPurchaseData() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final purchase = await db.purchasesDao.getPurchaseById(widget.purchaseId!);
    if (purchase == null) return;

    final supplier = purchase.supplierId == null
        ? null
        : await (db.select(db.suppliers)
              ..where((s) => s.id.equals(purchase.supplierId!)))
            .getSingleOrNull();
    final warehouse = purchase.warehouseId == null
        ? null
        : await (db.select(db.warehouses)
              ..where((w) => w.id.equals(purchase.warehouseId!)))
            .getSingleOrNull();
    final purchaseItems = await (db.select(db.purchaseItems)
          ..where((i) => i.purchaseId.equals(widget.purchaseId!)))
        .get();

    final loadedItems = <PurchaseItemData>[];
    for (final item in purchaseItems) {
      final product = await (db.select(db.products)
            ..where((p) => p.id.equals(item.productId)))
          .getSingleOrNull();
      if (product == null) continue;

      final conversions = await (db.select(db.unitConversions)
            ..where((u) => u.productId.equals(product.id)))
          .get();
      UnitConversion? selectedUnit;
      for (final conversion in conversions) {
        final matchesUnitId = item.unitId != null &&
            (conversion.id == item.unitId || conversion.unitName == item.unitId);
        final matchesFactor = item.unitId == null &&
            (conversion.factor - item.unitFactor).abs() < 0.0001;
        if (matchesUnitId || matchesFactor) {
          selectedUnit = conversion;
          break;
        }
      }

      loadedItems.add(
        PurchaseItemData(
          product: product,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discountAmount: item.discount,
          taxPercent: item.taxPercent,
          expiryDate: item.expiryDate,
          batchNumber: item.batchNumber,
          selectedUnit: selectedUnit,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _loadedPurchase = purchase;
      _selectedSupplier = supplier;
      _selectedWarehouse = warehouse;
      _selectedCurrency = purchase.currencyId;
      _paymentMethod = purchase.isCredit ? 'credit' : purchase.purchaseType;
      _selectedDate = purchase.date;
      _items
        ..clear()
        ..addAll(loadedItems);
      _discountController.text =
          purchase.discount == 0 ? '' : purchase.discount.toString();
      _shippingCostController.text =
          purchase.shippingCost == 0 ? '' : purchase.shippingCost.toString();
      _otherExpensesController.text =
          purchase.otherExpenses == 0 ? '' : purchase.otherExpenses.toString();
      _originalTax = purchase.tax;
      _taxController.text = purchase.tax == 0 ? '' : purchase.tax.toString();
    });
  }

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
      appBar: AppBar(
          title: Text(isEditMode ? 'تعديل فاتورة مشتريات' : 'فاتورة مشتريات')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_isLockedForEditing) _buildLockedBanner(),
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
                  onDelete: _isLockedForEditing
                      ? () => AppSnackBar.warning(
                            context,
                            'لا يمكن تعديل أصناف فاتورة مشتريات غير مسودة',
                          )
                      : () => setState(() => _items.removeAt(i)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLockedForEditing
                        ? null
                        : () => _showProductPicker(db),
                    icon: const Icon(Icons.search),
                    label: const Text('إضافة صنف موجود'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLockedForEditing
                        ? null
                        : () => _showQuickAddProduct(db),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('إضافة صنف جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSummary(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(db),
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
                'هذه الفاتورة ليست مسودة، لذلك لا يمكن تعديلها مباشرة. استخدم مستند تصحيح أو مرتجع عند الحاجة.',
              ),
            ),
          ],
        ),
      );

  Widget _buildHeader(AppDatabase db) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: SupplierPicker(
                        db: db,
                        value: _selectedSupplier,
                        onChanged: (v) =>
                            setState(() => _selectedSupplier = v))),
                Expanded(
                    child: WarehousePicker(
                        db: db,
                        value: _selectedWarehouse,
                        onChanged: (v) =>
                            setState(() => _selectedWarehouse = v))),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    items: ['cash', 'credit']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  ),
                ),
                Expanded(
                    child: StreamBuilder<List<Currency>>(
                      stream: db.select(db.currencies).watch(),
                      builder: (context, snapshot) {
                        final currencies = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          value:
                              currencies.any((c) => c.code == _selectedCurrency)
                                  ? _selectedCurrency
                                  : null,
                          decoration: const InputDecoration(labelText: 'العملة'),
                          items: currencies.map((c) => DropdownMenuItem(
                            value: c.code,
                            child: Text('${c.code} - ${c.name}'),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedCurrency = v),
                        );
                      },
                    )),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                ),
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
              _buildTaxEditableRow(),
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
          Text(title,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(_currencyFormatter.format(value),
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      );

  Widget _buildEditableRow(String title, TextEditingController controller,
          {bool enabled = true, String? helperText}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(title),
            ),
            SizedBox(
              width: 160,
              child: TextFormField(
                controller: controller,
                enabled: enabled,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  helperText: helperText,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) => _validateOptionalMoney(value, title),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      );

  Widget _buildTaxEditableRow() {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return _buildEditableRow('الضريبة', _taxController, enabled: false);
    }

    return FutureBuilder<bool>(
      future: sl<PermissionService>()
          .hasPermission(currentUser.id, PermissionCode.editTax),
      builder: (context, snapshot) {
        final canEditTax = snapshot.data == true;
        return _buildEditableRow(
          'الضريبة',
          _taxController,
          enabled: canEditTax,
          helperText: canEditTax ? 'اختياري' : 'تحتاج صلاحية تعديل الضريبة',
        );
      },
    );
  }

  String? _validateOptionalMoney(String? value, String fieldName) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return 'أدخل رقمًا صحيحًا في $fieldName';
    if (parsed < 0) return '$fieldName لا يمكن أن يكون سالبًا';
    return null;
  }

  Widget _buildFooter(AppDatabase db) => ElevatedButton(
        onPressed: _isSaving || _isLockedForEditing
            ? null
            : () => _savePurchase(db, post: true),
        child: _isSaving
            ? const CircularProgressIndicator()
            : const Text('حفظ وترحيل'),
      );

  Future<void> _savePurchase(AppDatabase db, {required bool post}) async {
    if (_isLockedForEditing) {
      AppSnackBar.warning(
        context,
        'لا يمكن تعديل فاتورة مشتريات غير مسودة. استخدم مستند تصحيح أو مرتجع بدلاً من التعديل المباشر.',
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackBar.warning(context, 'يرجى تصحيح الحقول المالية قبل الحفظ');
      return;
    }
    final currentUser =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    final taxChanged = (_tax - _originalTax).abs() > 0.0001;
    if (taxChanged &&
        (currentUser == null ||
            !await sl<PermissionService>()
                .hasPermission(currentUser.id, PermissionCode.editTax))) {
      AppSnackBar.error(context, 'ليست لديك صلاحية إدخال أو تعديل الضريبة');
      return;
    }

    if (_selectedSupplier == null) {
      AppSnackBar.warning(context, 'الرجاء اختيار المورد');
      return;
    }
    if (_selectedWarehouse == null) {
      AppSnackBar.warning(context, 'الرجاء اختيار المستودع');
      return;
    }
    if (_items.isEmpty) {
      AppSnackBar.warning(context, 'الرجاء إضافة أصناف');
      return;
    }

    for (var item in _items) {
      if (item.quantity <= 0) {
        AppSnackBar.warning(context, 'الكمية يجب أن تكون أكبر من صفر');
        return;
      }
      if (item.unitPrice < 0) {
        AppSnackBar.warning(context, 'السعر يجب أن يكون أكبر من أو يساوي صفر');
        return;
      }
    }

    setState(() => _isSaving = true);
    final String purchaseId;
    final bool isNew = !isEditMode;
    purchaseId = isNew ? const Uuid().v4() : widget.purchaseId!;

    try {
      final purchaseService = sl<PurchaseService>();
      final grnService = sl<GrnService>();
      final userId = currentUser?.id;

      await db.transaction(() async {
        final itemsCompanions = _items
            .map((item) => PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  productId: item.product.id,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  unitId: drift.Value(item.selectedUnit?.unitName),
                  unitFactor: drift.Value(item.selectedUnit?.factor ?? 1.0),
                  quantityInBaseUnit: drift.Value(
                      item.quantity * (item.selectedUnit?.factor ?? 1.0)),
                  price: item.subtotal,
                  discount: drift.Value(item.discountAmount),
                  tax: drift.Value(
                    (item.subtotal - item.discountAmount) *
                        (item.taxPercent / 100),
                  ),
                  taxPercent: drift.Value(item.taxPercent),
                  batchNumber: drift.Value(item.batchNumber),
                  expiryDate: drift.Value(item.expiryDate),
                ))
            .toList();

        if (isNew) {
          await db.purchasesDao.createPurchase(
            purchaseCompanion: PurchasesCompanion.insert(
              id: drift.Value(purchaseId),
              supplierId: drift.Value(_selectedSupplier!.id),
              warehouseId: drift.Value(_selectedWarehouse!.id),
              currencyId: drift.Value(_selectedCurrency),
              purchaseType: drift.Value(_paymentMethod),
              isCredit: drift.Value(_paymentMethod == 'credit'),
              total: _total,
              discount: drift.Value(_discount),
              tax: drift.Value(_tax),
              shippingCost: drift.Value(_shippingCost),
              otherExpenses: drift.Value(_otherExpenses),
              date: drift.Value(_selectedDate),
              status: const drift.Value(DocumentStatus.draft),
            ),
            itemsCompanions: itemsCompanions,
            userId: userId,
          );

          await sl<AuditService>().logCreate(
            'PurchaseInvoice',
            purchaseId,
            details: 'فاتورة مشتريات جديدة بقيمة ${_total.toStringAsFixed(2)}',
            userId: userId,
          );
        } else {
          await db.purchasesDao.updatePurchase(
            purchaseId: purchaseId,
            purchaseCompanion: PurchasesCompanion(
              supplierId: drift.Value(_selectedSupplier?.id),
              warehouseId: drift.Value(_selectedWarehouse?.id),
              currencyId: drift.Value(_selectedCurrency),
              purchaseType: drift.Value(_paymentMethod),
              isCredit: drift.Value(_paymentMethod == 'credit'),
              total: drift.Value(_total),
              discount: drift.Value(_discount),
              tax: drift.Value(_tax),
              shippingCost: drift.Value(_shippingCost),
              otherExpenses: drift.Value(_otherExpenses),
              date: drift.Value(_selectedDate),
            ),
            itemsCompanions: itemsCompanions,
            userId: userId,
          );

          await sl<AuditService>().logUpdate(
            'PurchaseInvoice',
            purchaseId,
            details: 'تم تعديل الفاتورة بقيمة ${_total.toStringAsFixed(2)}',
            userId: userId,
          );
        }

        if (post) {
          await grnService.createGrnFromPurchase(
            purchaseId: purchaseId,
            warehouseId: _selectedWarehouse!.id,
            notes: 'Auto-generated from Invoice',
          );

          await purchaseService.postPurchase(purchaseId);
          await sl<AuditService>().logUpdate(
            'PurchaseInvoice',
            purchaseId,
            details: 'تم ترحيل الفاتورة',
            userId: userId,
          );
        }
      });
      if (mounted) {
        AppSnackBar.success(
          context,
          post
              ? 'تم حفظ وترحيل الفاتورة وتحديث المخزون بنجاح'
              : isEditMode
                  ? 'تم تعديل الفاتورة بنجاح'
                  : 'تم حفظ المسودة بنجاح',
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('خطأ في حفظ الفاتورة: $e');
      String errorMessage = 'حدث خطأ غير متوقع أثناء الحفظ.';
      if (e.toString().contains('FOREIGN KEY constraint failed')) {
        errorMessage =
            'خطأ في الربط: تأكد من صحة البيانات المختارة (المستودع أو المورد أو الأصناف).';
      } else if (e.toString().contains('UNIQUE constraint failed')) {
        errorMessage =
            'خطأ في التكرار: رقم الفاتورة أو بيانات أخرى موجودة مسبقاً.';
      } else {
        errorMessage = 'فشل الحفظ: $e';
      }

      if (mounted) {
        AppSnackBar.error(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
