import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';
import 'package:drift/drift.dart' as drift;

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  @override
  Widget build(BuildContext context) {
    final db = sl<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('أوامر الشراء')),
      body: StreamBuilder<List<PurchaseOrder>>(
        stream: db.select(db.purchaseOrders).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text('أمر شراء رقم: ${order.orderNumber ?? order.id.substring(0,8)}'),
                subtitle: Text('التاريخ: ${order.date.toString().split(' ')[0]} | الحالة: ${order.status}'),
                trailing: Text(order.total.toStringAsFixed(2)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewOrder(db),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createNewOrder(AppDatabase db) async {
    // Basic navigation or dialog to create new PO
    await db.into(db.purchaseOrders).insert(PurchaseOrdersCompanion.insert(
      total: 0,
      status: const drift.Value('DRAFT'),
    ));
  }
}
