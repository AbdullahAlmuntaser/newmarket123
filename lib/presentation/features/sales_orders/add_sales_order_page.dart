import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/sales_order_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'sales_orders_provider.dart';

class AddSalesOrderPage extends StatefulWidget {
  final String? orderId;

  const AddSalesOrderPage({super.key, this.orderId});

  @override
  State<AddSalesOrderPage> createState() => _AddSalesOrderPageState();
}

class _AddSalesOrderPageState extends State<AddSalesOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String? _selectedCustomerId;
  final List<_OrderItem> _items = [];
  bool _isLoading = false;
  bool get _isEditing => widget.orderId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    final service = di.sl<SalesOrderService>();
    final order = await service.getOrderById(widget.orderId!);
    final items = await service.getOrderItems(widget.orderId!);

    if (order != null && mounted) {
      final db = di.sl<AppDatabase>();
      final productIds = items.map((i) => i.productId).toSet().toList();
      final products = await (db.select(db.products)
            ..where((p) => p.id.isIn(productIds)))
          .get();
      final nameMap = {for (final p in products) p.id: p.name};

      setState(() {
        _selectedCustomerId = order.customerId;
        _notesController.text = order.notes ?? '';
        _items.clear();
        for (final item in items) {
          _items.add(_OrderItem(
            productId: item.productId,
            productName: nameMap[item.productId] ?? '',
            quantity: item.quantity.toDouble(),
            price: item.price.toDouble(),
            unitId: item.unitId,
          ));
        }
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل الطلبية' : 'طلبية جديدة'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteOrder,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCustomerSelector(),
            const SizedBox(height: 16),
            _buildItemsSection(),
            const SizedBox(height: 16),
            _buildNotesField(),
            const SizedBox(height: 16),
            _buildTotalCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  Widget _buildCustomerSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('العميل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            StreamBuilder<List<Customer>>(
              stream: di
                  .sl<AppDatabase>()
                  .select(di.sl<AppDatabase>().customers)
                  .watch(),
              builder: (context, snapshot) {
                final customers = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'اختر العميل (اختياري)',
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('بدون عميل')),
                    ...customers.map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedCustomerId = val),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الأصناف',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة صنف'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('لم تتم إضافة أصناف بعد')),
              )
            else
              ..._items
                  .asMap()
                  .entries
                  .map((entry) => _buildItemRow(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, _OrderItem item) {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.productName.isNotEmpty
                        ? item.productName
                        : item.productId.substring(0, 8),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final qty = double.tryParse(val) ?? 0;
                      setState(() => _items[index].quantity = qty);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: item.price.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'السعر',
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final price = double.tryParse(val) ?? 0;
                      setState(() => _items[index].price = price);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'ملاحظات',
            hintText: 'أضف ملاحظات للطلبية...',
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    final total = _items.fold<double>(
        0, (sum, item) => sum + (item.quantity * item.price));
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الإجمالي:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${total.toStringAsFixed(2)} ر.س',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitOrder,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(_isEditing ? 'تحديث الطلبية' : 'إنشاء الطلبية',
                style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  void _addItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddProductDialog(),
    );
    if (result != null) {
      setState(() {
        _items.add(_OrderItem(
          productId: result['productId'],
          productName: result['productName'] ?? '',
          quantity: result['quantity'] ?? 1.0,
          price: result['price'] ?? 0.0,
        ));
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('أضف صنفاً واحداً على الأقل'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    final userId = di.sl<AuthProvider>().currentUser?.id;
    final provider = SalesOrdersProvider(di.sl<SalesOrderService>());

    final orderItems = _items
        .map((item) => SalesOrderItemData(
              productId: item.productId,
              quantity: Decimal.parse(item.quantity.toString()),
              price: Decimal.parse(item.price.toString()),
              unitId: item.unitId,
            ))
        .toList();

    bool success;
    if (_isEditing) {
      success = await provider.updateOrder(
        orderId: widget.orderId!,
        customerId: _selectedCustomerId,
        items: orderItems,
        notes: _notesController.text,
        userId: userId,
      );
    } else {
      success = await provider.createOrder(
        customerId: _selectedCustomerId,
        items: orderItems,
        notes: _notesController.text,
        userId: userId,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم التحديث بنجاح' : 'تم الإنشاء بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(provider.error ?? 'خطأ'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deleteOrder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطلبية'),
        content: const Text('هل تريد حذف هذه الطلبية نهائياً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = di.sl<AuthProvider>().currentUser?.id;
              final provider = SalesOrdersProvider(di.sl<SalesOrderService>());
              final success =
                  await provider.deleteOrder(widget.orderId!, userId: userId);
              if (mounted && success) {
                context.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _OrderItem {
  String productId;
  String productName;
  double quantity;
  double price;
  String? unitId;

  _OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.unitId,
  });
}

class _AddProductDialog extends StatefulWidget {
  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  String? _selectedProductId;
  String _searchQuery = '';
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '0');
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = di.sl<AppDatabase>();
    final products = await (db.select(db.products)
          ..where((p) => p.isActive.equals(true)))
        .get();
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.sku.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('إضافة صنف'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو الكود...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return RadioListTile<String>(
                          title: Text(product.name),
                          subtitle: Text(
                              '${product.sellPrice} ر.س - المخزون: ${product.stock}'),
                          value: product.id,
                          groupValue: _selectedProductId,
                          onChanged: (val) {
                            setState(() {
                              _selectedProductId = val;
                              _priceController.text =
                                  product.sellPrice.toString();
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyController,
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
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'السعر',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _selectedProductId == null
              ? null
              : () {
                  final product =
                      _products.firstWhere((p) => p.id == _selectedProductId);
                  Navigator.pop(context, {
                    'productId': _selectedProductId,
                    'productName': product.name,
                    'quantity': double.tryParse(_qtyController.text) ?? 1,
                    'price': double.tryParse(_priceController.text) ?? 0,
                  });
                },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
