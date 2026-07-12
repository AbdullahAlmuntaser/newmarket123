import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/core/services/sales_order_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;

class SalesOrderDetailPage extends StatefulWidget {
  final String orderId;

  const SalesOrderDetailPage({super.key, required this.orderId});

  @override
  State<SalesOrderDetailPage> createState() => _SalesOrderDetailPageState();
}

class _SalesOrderDetailPageState extends State<SalesOrderDetailPage> {
  late final SalesOrderService _service;
  SalesOrder? _order;
  List<SalesOrderItem> _items = [];
  Customer? _customer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = di.sl<SalesOrderService>();
    _loadData();
  }

  final Map<String, String> _productNames = {};

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _order = await _service.getOrderById(widget.orderId);
      _items = await _service.getOrderItems(widget.orderId);

      if (_order?.customerId != null) {
        final db = di.sl<AppDatabase>();
        _customer = await (db.select(db.customers)
              ..where((c) => c.id.equals(_order!.customerId!)))
            .getSingleOrNull();
      }

      if (_items.isNotEmpty) {
        final db = di.sl<AppDatabase>();
        final productIds = _items.map((i) => i.productId).toSet().toList();
        final products = await (db.select(db.products)
              ..where((p) => p.id.isIn(productIds)))
            .get();
        for (final p in products) {
          _productNames[p.id] = p.name;
        }
      }
    } catch (e) {
      debugPrint('Error loading order: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلبية')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلبية')),
        body: const Center(child: Text('الطلبية غير موجودة')),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final statusColor = _getStatusColor(_order!.status);
    final statusText = _getStatusText(_order!.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(_order!.orderNumber ?? 'تفاصيل الطلبية'),
        actions: [
          if (_order!.status != 'CANCELLED' && _order!.status != 'INVOICED')
            PopupMenuButton<String>(
              onSelected: _handleStatusChange,
              itemBuilder: (_) => [
                if (_order!.status == 'PENDING')
                  const PopupMenuItem(
                      value: 'ORDERED', child: Text('تم الطلب')),
                if (_order!.status == 'ORDERED')
                  const PopupMenuItem(value: 'READY', child: Text('جاهز')),
                if (_order!.status == 'READY')
                  const PopupMenuItem(
                      value: 'DELIVERED', child: Text('تم التوصيل')),
                const PopupMenuItem(value: 'CANCELLED', child: Text('إلغاء')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _order!.orderNumber ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(statusText,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.calendar_today, 'التاريخ',
                      dateFormat.format(_order!.createdAt)),
                  if (_customer != null)
                    _infoRow(Icons.person, 'العميل', _customer!.name),
                  if (_order!.notes != null && _order!.notes!.isNotEmpty)
                    _infoRow(Icons.note, 'ملاحظات', _order!.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الأصناف',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('لا توجد أصناف'),
                    ))
                  else
                    ..._items.map((item) => _buildItemTile(item)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '${_order!.total} ر.س',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _order!.status != 'CANCELLED' && _order!.status != 'INVOICED'
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/sales/orders/${_order!.id}/edit'),
                          icon: const Icon(Icons.edit),
                          label: const Text('تعديل'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _convertToSale,
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('تحويل لفاتورة'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _convertToPurchaseOrder,
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('أمر شراء'),
                        ),
                      ),
                    ],
                  ),
                )
              : null,
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildItemTile(SalesOrderItem item) {
    final total = item.quantity * item.price;
    final productName =
        _productNames[item.productId] ?? item.productId.substring(0, 8);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(productName),
      subtitle: Text('الكمية: ${item.quantity} × ${item.price}'),
      trailing: Text('$total ر.س',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  void _handleStatusChange(String newStatus) async {
    final userId = di.sl<AuthProvider>().currentUser?.id;
    try {
      await _service.updateStatus(
        widget.orderId,
        newStatus,
        userId: userId,
      );

      di.sl<NotificationService>().notify(
            title: 'تحديث حالة الطلبية',
            message:
                'تم تحديث حالة الطلبية ${_order?.orderNumber ?? ''} إلى ${_getStatusText(newStatus)}',
            category: 'orders',
            sourceKey: 'order:${widget.orderId}',
            severity: newStatus == 'CANCELLED' ? 'warning' : 'info',
          );

      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم التحديث: ${_getStatusText(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _convertToSale() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحويل لفاتورة'),
        content: const Text('هل تريد تحويل هذه الطلبية لفاتورة مبيعات؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تحويل')),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = di.sl<AuthProvider>().currentUser?.id;
      try {
        final sale =
            await _service.convertToSale(widget.orderId, userId: userId);
        di.sl<NotificationService>().notify(
              title: 'تحويل الطلبية لفاتورة',
              message:
                  'تم تحويل الطلبية ${_order?.orderNumber ?? ''} لفاتورة مبيعات',
              category: 'orders',
              sourceKey: 'order:${widget.orderId}',
              severity: 'info',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم التحويل بنجاح'),
                backgroundColor: Colors.green),
          );
          context.push('/sales/invoice/edit/${sale.id}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _convertToPurchaseOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحويل لأمر شراء'),
        content: const Text('هل تريد تحويل هذه الطلبية لأمر شراء من المورد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تحويل')),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = di.sl<AuthProvider>().currentUser?.id;
      try {
        final db = di.sl<AppDatabase>();
        final items = await _service.getOrderItems(widget.orderId);

        final poId = await db.into(db.purchaseOrders).insert(
              PurchaseOrdersCompanion.insert(
                total: drift.Value(_order!.total),
                status: const drift.Value('PENDING'),
                notes: drift.Value(
                    'محول من طلبية مبيعات: ${_order!.orderNumber ?? _order!.id.substring(0, 8)}'),
              ),
            );

        for (final item in items) {
          await db.into(db.purchaseOrderItems).insert(
                PurchaseOrderItemsCompanion.insert(
                  orderId: poId.toString(),
                  productId: item.productId,
                  quantity: drift.Value(item.quantity),
                  price: drift.Value(item.price),
                ),
              );
        }

        await _service.updateStatus(widget.orderId, 'DELIVERED',
            userId: userId);

        di.sl<NotificationService>().notify(
              title: 'تحويل الطلبية لأمر شراء',
              message:
                  'تم تحويل الطلبية ${_order?.orderNumber ?? ''} لأمر شراء',
              category: 'orders',
              sourceKey: 'order:${widget.orderId}',
              severity: 'info',
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم التحويل لأمر شراء بنجاح'),
                backgroundColor: Colors.green),
          );
          context.push('/purchases/orders');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'ORDERED':
        return Colors.blue;
      case 'READY':
        return Colors.green;
      case 'DELIVERED':
        return Colors.purple;
      case 'CANCELLED':
        return Colors.red;
      case 'INVOICED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'قيد الانتظار';
      case 'ORDERED':
        return 'تم الطلب';
      case 'READY':
        return 'جاهز';
      case 'DELIVERED':
        return 'تم التوصيل';
      case 'CANCELLED':
        return 'ملغى';
      case 'INVOICED':
        return 'محول لفاتورة';
      default:
        return status;
    }
  }
}
