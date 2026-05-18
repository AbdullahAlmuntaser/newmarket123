import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';

class WarehouseManagementPage extends StatelessWidget {
  const WarehouseManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final dao = db.warehousesDao;

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستودعات')),
      body: StreamBuilder<List<Warehouse>>(
        stream: dao.watchWarehouses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final warehouses = snapshot.data ?? [];

          if (warehouses.isEmpty) {
            return const Center(child: Text('لا توجد مستودعات مضافة'));
          }

          return ListView.builder(
            itemCount: warehouses.length,
            itemBuilder: (context, index) {
              final warehouse = warehouses[index];
              return ListTile(
                leading: Icon(
                  Icons.warehouse,
                  color: warehouse.isDefault
                      ? Theme.of(context).primaryColor
                      : null,
                ),
                title: Text(warehouse.name),
                subtitle: Text(warehouse.location ?? 'بدون موقع'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (warehouse.isDefault)
                      const Chip(
                        label: Text('الافتراضي'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    else
                      TextButton(
                        onPressed: () => dao.setDefaultWarehouse(warehouse.id),
                        child: const Text('تعيين كافتراضي'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: warehouse.isDefault
                          ? null
                          : () => _deleteWarehouse(context, db, warehouse.id),
                    ),
                  ],
                ),
                onTap: () => _showEditWarehouseDialog(context, db, warehouse),
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
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم المستودع'),
              autofocus: true,
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'الموقع'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                AppSnackBar.warning(context, 'اسم المستودع مطلوب');
                return;
              }
              try {
                await db.warehousesDao.createWarehouse(
                  WarehousesCompanion.insert(
                    name: nameController.text.trim(),
                    location: drift.Value(locationController.text.trim()),
                  ),
                );
                if (!context.mounted) return;
                AppSnackBar.success(context, 'تم إنشاء المستودع بنجاح');
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                AppSnackBar.error(context, 'فشل إنشاء المستودع: $e');
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditWarehouseDialog(
    BuildContext context,
    AppDatabase db,
    Warehouse warehouse,
  ) {
    final nameController = TextEditingController(text: warehouse.name);
    final locationController = TextEditingController(text: warehouse.location);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل مستودع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم المستودع'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'الموقع'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                AppSnackBar.warning(context, 'اسم المستودع مطلوب');
                return;
              }
              try {
                await db.warehousesDao.updateWarehouse(
                  warehouse.copyWith(
                    name: nameController.text.trim(),
                    location: drift.Value(locationController.text.trim()),
                  ),
                );
                if (!context.mounted) return;
                AppSnackBar.success(context, 'تم تحديث المستودع بنجاح');
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                AppSnackBar.error(context, 'فشل تحديث المستودع: $e');
              }
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  void _deleteWarehouse(BuildContext context, AppDatabase db, String id) async {
    final hasStock = await db.warehousesDao.hasStock(id);
    if (hasStock) {
      if (context.mounted) {
        AppSnackBar.warning(
          context,
          'لا يمكن حذف المستودع لأنه يحتوي على مخزون.',
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المستودع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      try {
        await db.warehousesDao.deleteWarehouse(id);
        if (!context.mounted) return;
        AppSnackBar.success(context, 'تم حذف المستودع بنجاح');
      } catch (e) {
        if (!context.mounted) return;
        AppSnackBar.error(context, 'فشل حذف المستودع: $e');
      }
    }
  }
}
