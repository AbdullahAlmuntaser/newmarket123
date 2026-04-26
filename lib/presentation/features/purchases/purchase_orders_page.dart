import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/reorder_service.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  final ReorderService _reorderService = sl<ReorderService>();
  final AppDatabase db = sl<AppDatabase>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أوامر الشراء')),
      body: StreamBuilder<List<PurchaseOrder>>(
        stream: db.select(db.purchaseOrders).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text('أمر شراء رقم: ${order.orderNumber ?? order.id}'),
                subtitle: Text(
                  'التاريخ: ${order.date.toString().split(' ')[0]} | الحالة: ${order.status}',
                ),
                trailing: Text(order.total.toStringAsFixed(2)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _generateAutoOrder(),
        label: _isLoading
            ? const Text('جاري الإنشاء...')
            : const Text('توليد أوامر شراء تلقائية'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Future<void> _generateAutoOrder() async {
    setState(() => _isLoading = true);
    try {
      await _reorderService.generateAutoPurchaseOrders(warehouseId: '1');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم توليد أوامر الشراء بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
