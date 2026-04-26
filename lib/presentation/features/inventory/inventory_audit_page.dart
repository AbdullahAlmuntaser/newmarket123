import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

class InventoryAuditPage extends StatefulWidget {
  const InventoryAuditPage({super.key});

  @override
  State<InventoryAuditPage> createState() => _InventoryAuditPageState();
}

class _InventoryAuditPageState extends State<InventoryAuditPage> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('محاضر الجرد')),
      body: StreamBuilder<List<InventoryAudit>>(
        stream: db.select(db.inventoryAudits).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final audits = snapshot.data!;
          return ListView.builder(
            itemCount: audits.length,
            itemBuilder: (context, index) {
              final audit = audits[index];
              return ListTile(
                title: Text('محضر جرد: ${audit.id.substring(0, 8)}'),
                subtitle: Text('التاريخ: ${audit.auditDate.toString().split(' ')[0]}'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _navigateToDetails(context, audit),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createAudit(db),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createAudit(AppDatabase db) async {
    final auditId = const Uuid().v4();
    await db.into(db.inventoryAudits).insert(InventoryAuditsCompanion.insert(
      id: drift.Value(auditId),
      auditDate: drift.Value(DateTime.now()),
    ));
    // في الواقع هنا يجب إضافة أصناف الجرد تلقائياً بناءً على المخزن
  }

  void _navigateToDetails(BuildContext context, InventoryAudit audit) {
    // Navigation to details page to be implemented
  }
}
