import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/inventory_audit_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:provider/provider.dart';

class InventoryAuditDetailsPage extends StatelessWidget {
  final InventoryAudit audit;
  const InventoryAuditDetailsPage({super.key, required this.audit});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل محضر الجرد')),
      body: StreamBuilder<List<InventoryAuditItem>>(
        stream: (db.select(db.inventoryAuditItems)..where((i) => i.auditId.equals(audit.id))).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text('المنتج: ${item.productId}'),
                subtitle: Text('الدفترية: ${item.systemStock} | الفعلية: ${item.actualStock}'),
                trailing: Text('الفرق: ${item.difference}', style: TextStyle(color: item.difference != 0 ? Colors.red : Colors.green)),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: ElevatedButton(
          onPressed: () async {
            await sl<InventoryAuditService>().completeAudit(audit.id);
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل فروقات الجرد بنجاح')));
                Navigator.pop(context);
            }
          },
          child: const Text('ترحيل وتسوية المخزون'),
        ),
      ),
    );
  }
}
