import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/presentation/features/inventory/serial_number_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';

class SerialNumbersPage extends StatefulWidget {
  const SerialNumbersPage({super.key});

  @override
  State<SerialNumbersPage> createState() => _SerialNumbersPageState();
}

class _SerialNumbersPageState extends State<SerialNumbersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SerialNumberProvider>();
      provider.loadDropdownData();
      provider.loadSerialNumbers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SerialNumberProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرقام التسلسل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'السجل',
            onPressed: () => _showHistoryDialog(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(context, provider),
          const Divider(height: 1),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.serialNumbers.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد أرقام تسلسل',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : _buildSerialNumberList(provider),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'bulk',
            onPressed: () => _showBulkRegisterDialog(context, provider),
            child: const Icon(Icons.playlist_add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => _showAddDialog(context, provider),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, SerialNumberProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: provider.filterProductId,
                  decoration: const InputDecoration(
                    labelText: 'المنتج',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('الكل'),
                    ),
                    ...provider.products.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) {
                    provider.loadSerialNumbers(
                      productId: val,
                      warehouseId: provider.filterWarehouseId,
                      status: provider.filterStatus,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: provider.filterWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'المستودع',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('الكل'),
                    ),
                    ...provider.warehouses.map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(
                            w.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) {
                    provider.loadSerialNumbers(
                      productId: provider.filterProductId,
                      warehouseId: val,
                      status: provider.filterStatus,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusFilter(provider),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(SerialNumberProvider provider) {
    final statuses = [
      {'label': 'الكل', 'value': null, 'color': Colors.grey},
      {'label': 'في المخزون', 'value': 'IN_STOCK', 'color': Colors.green},
      {'label': 'تم البيع', 'value': 'SOLD', 'color': Colors.blue},
      {'label': 'محجوز', 'value': 'RESERVED', 'color': Colors.orange},
      {'label': 'مرجع', 'value': 'RETURNED', 'color': Colors.grey},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final s = statuses[index];
          final isSelected = provider.filterStatus == s['value'];
          final color = s['color'] as Color;
          return FilterChip(
            label: Text(
              s['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 12,
              ),
            ),
            selected: isSelected,
            selectedColor: color,
            backgroundColor: color.withOpacity(0.1),
            side: BorderSide(color: color),
            onSelected: (_) {
              provider.loadSerialNumbers(
                productId: provider.filterProductId,
                warehouseId: provider.filterWarehouseId,
                status: s['value'] as String?,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSerialNumberList(SerialNumberProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.loadSerialNumbers(
        productId: provider.filterProductId,
        warehouseId: provider.filterWarehouseId,
        status: provider.filterStatus,
      ),
      child: ListView.builder(
        itemCount: provider.serialNumbers.length,
        itemBuilder: (context, index) {
          final sn = provider.serialNumbers[index];
          return _buildSerialNumberTile(context, sn, provider);
        },
      ),
    );
  }

  Widget _buildSerialNumberTile(
    BuildContext context,
    SerialNumber sn,
    SerialNumberProvider provider,
  ) {
    final db = sl<AppDatabase>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildStatusIcon(sn.status),
        title: Text(
          sn.serialNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Product?>(
              future: (db.select(db.products)
                    ..where((p) => p.id.equals(sn.productId)))
                  .getSingleOrNull(),
              builder: (context, snapshot) => Text(
                'المنتج: ${snapshot.data?.name ?? sn.productId}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            FutureBuilder<Warehouse?>(
              future: (db.select(db.warehouses)
                    ..where((w) => w.id.equals(sn.warehouseId)))
                  .getSingleOrNull(),
              builder: (context, snapshot) => Text(
                'المستودع: ${snapshot.data?.name ?? sn.warehouseId}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (sn.batchId != null)
              Text(
                'الدفعة: ${sn.batchId}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (sn.receivedDate != null)
              Text(
                'تاريخ الاستلام: ${_formatDate(sn.receivedDate!)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(
            context,
            value,
            sn,
            provider,
          ),
          itemBuilder: (context) {
            final items = <PopupMenuItem<String>>[];
            if (sn.status == 'IN_STOCK') {
              items.add(const PopupMenuItem(
                value: 'reserve',
                child: Text('حجز'),
              ));
              items.add(const PopupMenuItem(
                value: 'sold',
                child: Text('تم البيع'),
              ));
              items.add(const PopupMenuItem(
                value: 'returned',
                child: Text('مرجع'),
              ));
            } else if (sn.status == 'RESERVED') {
              items.add(const PopupMenuItem(
                value: 'sold',
                child: Text('تم البيع'),
              ));
              items.add(const PopupMenuItem(
                value: 'returned',
                child: Text('مرجع'),
              ));
            } else if (sn.status == 'RETURNED') {
              items.add(const PopupMenuItem(
                value: 'restock',
                child: Text('إعادة للمخزون'),
              ));
            }
            return items;
          },
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'IN_STOCK':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'SOLD':
        color = Colors.blue;
        icon = Icons.shopping_cart;
        break;
      case 'RESERVED':
        color = Colors.orange;
        icon = Icons.lock;
        break;
      case 'RETURNED':
        color = Colors.grey;
        icon = Icons.undo;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    SerialNumber sn,
    SerialNumberProvider provider,
  ) async {
    switch (action) {
      case 'reserve':
        _showReserveDialog(context, sn, provider);
        break;
      case 'sold':
        _showSoldDialog(context, sn, provider);
        break;
      case 'returned':
        _showReturnedConfirmDialog(context, sn, provider);
        break;
      case 'restock':
        _restockItem(sn, provider);
        break;
    }
  }

  void _showAddDialog(BuildContext context, SerialNumberProvider provider) {
    final serialController = TextEditingController();
    String? selectedProductId;
    String? selectedWarehouseId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة رقم تسلسل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'المنتج *',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.products
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedProductId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'المستودع *',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.warehouses
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedWarehouseId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: serialController,
                  decoration: const InputDecoration(
                    labelText: 'رقم التسلسل *',
                    border: OutlineInputBorder(),
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedProductId == null ||
                    selectedWarehouseId == null ||
                    serialController.text.trim().isEmpty) {
                  AppSnackBar.warning(ctx, 'يرجى ملء جميع الحقول المطلوبة');
                  return;
                }
                Navigator.pop(ctx);
                final result = await provider.registerSerialNumber(
                  productId: selectedProductId!,
                  serialNumber: serialController.text.trim(),
                  warehouseId: selectedWarehouseId!,
                );
                if (context.mounted) {
                  if (result != null) {
                    AppSnackBar.success(context, 'تم إضافة رقم التسلسل بنجاح');
                  } else {
                    AppSnackBar.error(
                        context, provider.error ?? 'حدث خطأ');
                  }
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkRegisterDialog(
    BuildContext context,
    SerialNumberProvider provider,
  ) {
    final textController = TextEditingController();
    String? selectedProductId;
    String? selectedWarehouseId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة أرقام تسلسل متعددة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'المنتج *',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.products
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedProductId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'المستودع *',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.warehouses
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedWarehouseId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'أرقام التسلسل (رقم واحد في كل سطر) *',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  textDirection: TextDirection.ltr,
                  maxLines: 8,
                  minLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedProductId == null ||
                    selectedWarehouseId == null ||
                    textController.text.trim().isEmpty) {
                  AppSnackBar.warning(ctx, 'يرجى ملء جميع الحقول المطلوبة');
                  return;
                }
                final lines = textController.text
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .toList();
                if (lines.isEmpty) {
                  AppSnackBar.warning(
                      ctx, 'يرجى إدخال أرقام تسلسل واحدة على الأقل');
                  return;
                }
                Navigator.pop(ctx);
                final count = await provider.bulkRegister(
                  productId: selectedProductId!,
                  warehouseId: selectedWarehouseId!,
                  serialNumbers: lines,
                );
                if (context.mounted) {
                  AppSnackBar.success(
                    context,
                    'تم تسجيل $count رقم تسلسل من ${lines.length}',
                  );
                }
              },
              child: const Text('تسجيل الكل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReserveDialog(
    BuildContext context,
    SerialNumber sn,
    SerialNumberProvider provider,
  ) {
    final orderController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حجز رقم التسلسل'),
        content: TextField(
          controller: orderController,
          decoration: const InputDecoration(
            labelText: 'رقم طلب البيع *',
            border: OutlineInputBorder(),
          ),
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (orderController.text.trim().isEmpty) {
                AppSnackBar.warning(ctx, 'يرجى إدخال رقم طلب البيع');
                return;
              }
              Navigator.pop(ctx);
              await provider.reserve(
                serialNumberId: sn.id,
                salesOrderId: orderController.text.trim(),
              );
              if (context.mounted) {
                AppSnackBar.success(context, 'تم حجز رقم التسلسل');
              }
            },
            child: const Text('حجز'),
          ),
        ],
      ),
    );
  }

  void _showSoldDialog(
    BuildContext context,
    SerialNumber sn,
    SerialNumberProvider provider,
  ) {
    final saleIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل بيع رقم التسلسل'),
        content: TextField(
          controller: saleIdController,
          decoration: const InputDecoration(
            labelText: 'رقم البيع *',
            border: OutlineInputBorder(),
          ),
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (saleIdController.text.trim().isEmpty) {
                AppSnackBar.warning(ctx, 'يرجى إدخال رقم البيع');
                return;
              }
              Navigator.pop(ctx);
              await provider.markAsSold(
                serialNumberId: sn.id,
                saleId: saleIdController.text.trim(),
              );
              if (context.mounted) {
                AppSnackBar.success(context, 'تم تسجيل البيع بنجاح');
              }
            },
            child: const Text('تسجيل البيع'),
          ),
        ],
      ),
    );
  }

  void _showReturnedConfirmDialog(
    BuildContext context,
    SerialNumber sn,
    SerialNumberProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإرجاع'),
        content: Text(
          'هل تريد تسجيل رقم التسلسل "${sn.serialNumber}" كمرجع؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.markAsReturned(
                serialNumberId: sn.id,
              );
              if (context.mounted) {
                AppSnackBar.success(context, 'تم تسجيل الإرجاع بنجاح');
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _restockItem(SerialNumber sn, SerialNumberProvider provider) async {
    await provider.registerSerialNumber(
      productId: sn.productId,
      serialNumber: sn.serialNumber,
      warehouseId: sn.warehouseId,
    );
  }

  void _showHistoryDialog(
    BuildContext context,
    SerialNumberProvider provider,
  ) {
    String? historyProductId;
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('سجل أرقام التسلسل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: historyProductId,
                  decoration: const InputDecoration(
                    labelText: 'المنتج (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('الكل'),
                    ),
                    ...provider.products.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        )),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => historyProductId = val),
                ),
                const SizedBox(height: 12),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('من تاريخ'),
                  subtitle: Text(
                    startDate != null ? _formatDate(startDate!) : 'غير محدد',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إلى تاريخ'),
                  subtitle: Text(
                    endDate != null ? _formatDate(endDate!) : 'غير محدد',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.loadSerialNumbers();
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.loadHistory(
                  productId: historyProductId,
                  startDate: startDate,
                  endDate: endDate,
                );
              },
              child: const Text('عرض السجل'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
