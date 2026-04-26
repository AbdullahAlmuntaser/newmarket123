import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/purchase_converter.dart';
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
      body: StreamBuilder<List<TypedResult>>(
        stream: (db.select(db.purchaseOrders).join([
          leftOuterJoin(db.suppliers, db.suppliers.id.equalsExp(db.purchaseOrders.supplierId)),
        ])).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final order = rows[index].readTable(db.purchaseOrders);
              final supplier = rows[index].readTableOrNull(db.suppliers);
              return ListTile(
                title: Text('أمر شراء: ${order.orderNumber ?? order.id.substring(0, 8)}'),
                subtitle: Text(
                  'المورد: ${supplier?.name ?? 'غير معروف'} | الحالة: ${order.status}',
                ),
                trailing: Text(order.total.toStringAsFixed(2)),
                onTap: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تأكيد'),
                      content: Text('تحويل أمر الشراء ${order.orderNumber} إلى فاتورة؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تحويل')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await PurchaseConverter(db).convertOrderToInvoice(order.id);
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('تم التحويل بنجاح')));
                    }
                  }
                },
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
