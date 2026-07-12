import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:intl/intl.dart';

class BeginningOfPeriodPage extends StatefulWidget {
  const BeginningOfPeriodPage({super.key});

  @override
  State<BeginningOfPeriodPage> createState() => _BeginningOfPeriodPageState();
}

class _BeginningOfPeriodPageState extends State<BeginningOfPeriodPage> {
  String? _selectedWarehouseId;
  List<Warehouse> _warehouses = [];
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _costControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime _periodDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _costControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializePage() async {
    final db = context.read<AppDatabase>();
    _warehouses = await (db.select(db.warehouses)
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();

    if (_warehouses.isNotEmpty) {
      _selectedWarehouseId = _warehouses.first.id;
      await _loadProducts();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadProducts() async {
    if (_selectedWarehouseId == null) return;

    final db = context.read<AppDatabase>();
    _products = await (db.select(db.products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();

    for (final product in _products) {
      _quantityControllers[product.id] = TextEditingController(
        text: product.stock.toString(),
      );
      _costControllers[product.id] = TextEditingController(
        text: product.buyPrice.toString(),
      );
    }

    _filteredProducts = List.from(_products);
    setState(() {});
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products
            .where((p) =>
                p.name.toLowerCase().contains(query.toLowerCase()) ||
                p.sku.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أول المدة - تسوية المخزون الأولي'),
        actions: [
          if (!_isLoading && _products.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveBeginningBalances,
              tooltip: 'حفظ الأرصدة الأولية',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderSection(),
                _buildFilterSection(),
                Expanded(child: _buildProductsList()),
                _buildSaveBar(),
              ],
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warehouse, size: 20),
                const SizedBox(width: 8),
                const Text('المستودع:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedWarehouseId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _warehouses
                        .map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      setState(() => _selectedWarehouseId = val);
                      await _loadProducts();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                const Text('تاريخ الفترة:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _periodDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _periodDate = picked);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd').format(_periodDate)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'عدد المنتجات: ${_filteredProducts.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'بحث بالاسم أو الكود...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: _filterProducts,
      ),
    );
  }

  Widget _buildProductsList() {
    if (_filteredProducts.isEmpty) {
      return const Center(child: Text('لا توجد منتجات'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'SKU: ${product.sku}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _quantityControllers[product.id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _costControllers[product.id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'التكلفة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'إجمالي المنتجات: ${_filteredProducts.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveBeginningBalances,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('حفظ الأرصدة الأولية'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBeginningBalances() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حفظ الأرصدة الأولية'),
        content: const Text(
            'سيتم تحديث كمية وتكلفة جميع المنتجات المعدلة. هل تريد المتابعة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      if (!mounted) return;
      final db = context.read<AppDatabase>();
      int updatedCount = 0;

      await db.transaction(() async {
        for (final product in _filteredProducts) {
          final qtyText = _quantityControllers[product.id]?.text ?? '0';
          final costText = _costControllers[product.id]?.text ?? '0';

          final newQty = Decimal.tryParse(qtyText) ?? Decimal.zero;
          final newCost = Decimal.tryParse(costText) ?? Decimal.zero;

          if (newQty != product.stock || newCost != product.buyPrice) {
            await (db.update(db.products)
                  ..where((p) => p.id.equals(product.id)))
                .write(ProductsCompanion(
              stock: Value(newQty),
              buyPrice: Value(newCost),
              updatedAt: Value(DateTime.now()),
            ));

            await db.into(db.inventoryTransactions).insert(
                  InventoryTransactionsCompanion.insert(
                    productId: product.id,
                    warehouseId: _selectedWarehouseId!,
                    quantity: Value(newQty),
                    type: 'BEGINNING_BALANCE',
                    referenceId: product.id,
                  ),
                );

            await db.into(db.auditLogs).insert(
                  AuditLogsCompanion.insert(
                    action: 'BEGINNING_BALANCE',
                    targetEntity: 'PRODUCT',
                    entityId: product.id,
                    details:
                        Value('Beginning balance: qty=$newQty, cost=$newCost'),
                  ),
                );

            updatedCount++;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الأرصدة الأولية لـ $updatedCount منتج'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
