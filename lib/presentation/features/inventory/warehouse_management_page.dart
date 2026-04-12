import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;

class WarehouseManagementPage extends StatelessWidget {
  const WarehouseManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستودعات')),
      body: StreamBuilder<List<Warehouse>>(
        stream: db.select(db.warehouses).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final warehouses = snapshot.data!;
          
          return ListView.builder(
            itemCount: warehouses.length,
            itemBuilder: (context, index) {
              final warehouse = warehouses[index];
              return ListTile(
                leading: const Icon(Icons.warehouse),
                title: Text(warehouse.name),
                subtitle: Text(warehouse.location ?? 'بدون موقع'),
                trailing: warehouse.isDefault 
                  ? const Chip(label: Text('الافتراضي'))
                  : IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteWarehouse(context, db, warehouse.id),
                    ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWarehouseDialog(context, db),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWarehouseDialog(BuildContext context, AppDatabase db) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مستودع جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المستودع')),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: 'الموقع')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await db.into(db.warehouses).insert(
                  WarehousesCompanion.insert(
                    name: nameController.text,
                    location: drift.Value(locationController.text),
                  )
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteWarehouse(BuildContext context, AppDatabase db, String id) async {
    // التحقق من وجود مخزون في المستودع قبل الحذف
    final batches = await (db.select(db.productBatches)..where((t) => t.warehouseId.equals(id))).get();
    if (batches.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حذف المستودع لأنه يحتوي على مخزون.')),
        );
      }
      return;
    }
    await (db.delete(db.warehouses)..where((t) => t.id.equals(id))).go();
  }
}
