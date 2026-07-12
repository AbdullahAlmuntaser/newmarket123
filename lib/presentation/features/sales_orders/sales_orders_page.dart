import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/core/services/sales_order_service.dart';
import 'package:supermarket/core/services/permission_service.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'sales_orders_provider.dart';

class SalesOrdersPage extends StatefulWidget {
  const SalesOrdersPage({super.key});

  @override
  State<SalesOrdersPage> createState() => _SalesOrdersPageState();
}

class _SalesOrdersPageState extends State<SalesOrdersPage> {
  late final SalesOrdersProvider _provider;
  String _searchQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _provider = SalesOrdersProvider(di.sl<SalesOrderService>());
    _provider.loadOrders();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبيات العملاء'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _provider.loadOrders,
            ),
          ],
        ),
        body: Consumer<SalesOrdersProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                _buildSearchBar(),
                _buildStatusTabs(provider),
                Expanded(
                  child: _buildOrdersList(provider),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final userId = di.sl<AuthProvider>().currentUser?.id ?? '';
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final hasPermission = await di
                .sl<PermissionService>()
                .hasPermission(userId, PermissionCode.createSalesOrder);
            if (!mounted) return;
            if (hasPermission) {
              nav.pushNamed('/sales/orders/new');
            } else {
              messenger.showSnackBar(
                const SnackBar(
                    content: Text('غير مصرح لك بإنشاء طلبية'),
                    backgroundColor: Colors.red),
              );
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('طلبية جديدة'),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث برقم الطلبية أو اسم العميل...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFrom ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateFrom = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'من',
                  suffixIcon: Icon(Icons.calendar_today, size: 16),
                ),
                child: Text(
                  _dateFrom != null
                      ? DateFormat('MM/dd').format(_dateFrom!)
                      : '',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateTo ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateTo = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'إلى',
                  suffixIcon: Icon(Icons.calendar_today, size: 16),
                ),
                child: Text(
                  _dateTo != null ? DateFormat('MM/dd').format(_dateTo!) : '',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (_dateFrom != null || _dateTo != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => setState(() {
                _dateFrom = null;
                _dateTo = null;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(SalesOrdersProvider provider) {
    final statuses = [
      {'key': 'ALL', 'label': 'الكل', 'icon': Icons.list},
      {
        'key': 'PENDING',
        'label': 'قيد الانتظار',
        'icon': Icons.hourglass_empty
      },
      {'key': 'ORDERED', 'label': 'تم الطلب', 'icon': Icons.shopping_cart},
      {'key': 'READY', 'label': 'جاهز', 'icon': Icons.check_circle_outline},
      {
        'key': 'DELIVERED',
        'label': 'تم التوصيل',
        'icon': Icons.delivery_dining
      },
      {'key': 'CANCELLED', 'label': 'ملغى', 'icon': Icons.cancel},
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final s = statuses[index];
          final isSelected = provider.statusFilter == s['key'];
          final count = s['key'] == 'ALL'
              ? provider.orders.length
              : (provider.statusCounts[s['key']] ?? 0);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Text('${s['label']} ($count)'),
              avatar: Icon(s['icon'] as IconData, size: 18),
              onSelected: (_) => provider.setStatusFilter(s['key'] as String),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(SalesOrdersProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(provider.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: provider.loadOrders,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (provider.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('لا توجد طلبيات',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    List<SalesOrder> filteredOrders = provider.orders;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredOrders = filteredOrders.where((o) {
        return (o.orderNumber?.toLowerCase().contains(query) ?? false) ||
            o.id.toLowerCase().contains(query);
      }).toList();
    }

    if (_dateFrom != null) {
      filteredOrders = filteredOrders
          .where((o) =>
              o.createdAt.isAfter(_dateFrom!.subtract(const Duration(days: 1))))
          .toList();
    }
    if (_dateTo != null) {
      final endOfDay = _dateTo!.add(const Duration(days: 1));
      filteredOrders =
          filteredOrders.where((o) => o.createdAt.isBefore(endOfDay)).toList();
    }

    return RefreshIndicator(
      onRefresh: provider.loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) => _buildOrderCard(filteredOrders[index]),
      ),
    );
  }

  Widget _buildOrderCard(SalesOrder order) {
    final statusColor = _getStatusColor(order.status);
    final statusText = _getStatusText(order.status);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(25),
          child:
              Icon(_getStatusIcon(order.status), color: statusColor, size: 20),
        ),
        title: Text(
          order.orderNumber ?? order.id.substring(0, 8),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: statusColor),
                const SizedBox(width: 4),
                Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 12)),
                const SizedBox(width: 12),
                Text(dateFormat.format(order.createdAt),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${order.total} ر.س',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleAction(value, order),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('عرض التفاصيل')),
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            if (order.status == 'PENDING')
              const PopupMenuItem(
                  value: 'ordered', child: Text('تحديث: تم الطلب')),
            if (order.status == 'ORDERED')
              const PopupMenuItem(value: 'ready', child: Text('تحديث: جاهز')),
            if (order.status == 'READY')
              const PopupMenuItem(
                  value: 'delivered', child: Text('تحديث: تم التوصيل')),
            if (order.status != 'CANCELLED' && order.status != 'INVOICED')
              const PopupMenuItem(
                  value: 'convert', child: Text('تحويل لفاتورة')),
            if (order.status != 'CANCELLED' && order.status != 'INVOICED')
              const PopupMenuItem(
                  value: 'convertPurchase', child: Text('تحويل لأمر شراء')),
            if (order.status != 'CANCELLED' && order.status != 'INVOICED')
              const PopupMenuItem(value: 'cancel', child: Text('إلغاء')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('حذف', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => context.push('/sales/orders/${order.id}'),
      ),
    );
  }

  void _handleAction(String action, SalesOrder order) async {
    final userId = di.sl<AuthProvider>().currentUser?.id;
    switch (action) {
      case 'view':
        context.push('/sales/orders/${order.id}');
        break;
      case 'edit':
        context.push('/sales/orders/${order.id}/edit');
        break;
      case 'ordered':
        await _provider.updateStatus(order.id, 'ORDERED', userId: userId);
        break;
      case 'ready':
        await _provider.updateStatus(order.id, 'READY', userId: userId);
        break;
      case 'delivered':
        await _provider.updateStatus(order.id, 'DELIVERED', userId: userId);
        break;
      case 'convert':
        _showConvertDialog(order);
        break;
      case 'convertPurchase':
        _showConvertPurchaseDialog(order);
        break;
      case 'cancel':
        _showCancelDialog(order);
        break;
      case 'delete':
        _showDeleteDialog(order);
        break;
    }
  }

  void _showConvertDialog(SalesOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحويل لفاتورة'),
        content: const Text('هل تريد تحويل هذه الطلبية لفاتورة مبيعات؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = di.sl<AuthProvider>().currentUser?.id;
              try {
                await di
                    .sl<SalesOrderService>()
                    .convertToSale(order.id, userId: userId);
                di.sl<NotificationService>().notify(
                      title: 'تحويل الطلبية لفاتورة',
                      message:
                          'تم تحويل الطلبية ${order.orderNumber ?? ''} لفاتورة مبيعات',
                      category: 'orders',
                      sourceKey: 'order:${order.id}',
                      severity: 'info',
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم التحويل بنجاح'),
                        backgroundColor: Colors.green),
                  );
                  _provider.loadOrders();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('تحويل'),
          ),
        ],
      ),
    );
  }

  void _showConvertPurchaseDialog(SalesOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحويل لأمر شراء'),
        content: const Text('هل تريد تحويل هذه الطلبية لأمر شراء من المورد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = di.sl<AuthProvider>().currentUser?.id;
              try {
                final db = di.sl<AppDatabase>();
                final service = di.sl<SalesOrderService>();
                final items = await service.getOrderItems(order.id);

                final poId = await db.into(db.purchaseOrders).insert(
                      PurchaseOrdersCompanion.insert(
                        total: drift.Value(order.total),
                        status: const drift.Value('PENDING'),
                        notes: drift.Value(
                            'محول من طلبية مبيعات: ${order.orderNumber ?? order.id.substring(0, 8)}'),
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

                await service.updateStatus(order.id, 'DELIVERED',
                    userId: userId);

                di.sl<NotificationService>().notify(
                      title: 'تحويل الطلبية لأمر شراء',
                      message:
                          'تم تحويل الطلبية ${order.orderNumber ?? ''} لأمر شراء',
                      category: 'orders',
                      sourceKey: 'order:${order.id}',
                      severity: 'info',
                    );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم التحويل لأمر شراء بنجاح'),
                        backgroundColor: Colors.green),
                  );
                  _provider.loadOrders();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('تحويل'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(SalesOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلبية'),
        content: const Text('هل تريد إلغاء هذه الطلبية؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لا')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = di.sl<AuthProvider>().currentUser?.id;
              await _provider.cancelOrder(order.id, userId: userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('إلغاء الطلبية'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(SalesOrder order) {
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
              await _provider.deleteOrder(order.id, userId: userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'ORDERED':
        return Icons.shopping_cart;
      case 'READY':
        return Icons.check_circle_outline;
      case 'DELIVERED':
        return Icons.delivery_dining;
      case 'CANCELLED':
        return Icons.cancel;
      case 'INVOICED':
        return Icons.receipt_long;
      default:
        return Icons.help_outline;
    }
  }
}
