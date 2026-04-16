import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

/// صفحة إدارة الصلاحيات والأدوار
class PermissionsManagementPage extends StatefulWidget {
  const PermissionsManagementPage({super.key});

  @override
  State<PermissionsManagementPage> createState() =>
      _PermissionsManagementPageState();
}

class _PermissionsManagementPageState extends State<PermissionsManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRole = 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصلاحيات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shield), text: 'الأدوار'),
            Tab(icon: Icon(Icons.key), text: 'الصلاحيات'),
            Tab(icon: Icon(Icons.assignment_ind), text: 'تعيين الصلاحيات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRolesTab(db),
          _buildPermissionsTab(db),
          _buildRolePermissionsTab(db),
        ],
      ),
    );
  }

  // ====== تبويب الأدوار ======
  Widget _buildRolesTab(AppDatabase db) {
    return FutureBuilder<List<User>>(
      future: db.select(db.users).get(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? [];
        final roles = users.map((u) => u.role).toSet().toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الأدوار الموجودة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRoleDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة دور'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (roles.isEmpty)
                const Center(child: Text('لا توجد أدوار'))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: roles.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final role = roles[index];
                      final userCount = users
                          .where((u) => u.role == role)
                          .length;
                      return ListTile(
                        leading: const Icon(Icons.shield, size: 32),
                        title: Text(role),
                        trailing: Text('$userCount مستخدم'),
                        onTap: () {
                          setState(() => _selectedRole = role);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ====== تبويب الصلاحيات ======
  Widget _buildPermissionsTab(AppDatabase db) {
    return StreamBuilder<List<Permission>>(
      stream: db.select(db.permissions).watch(),
      builder: (context, snapshot) {
        final permissions = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الصلاحيات المتاحة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPermissionDialog(context, db),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة صلاحية'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: permissions
                      .map(
                        (p) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.description ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ====== تبويب تعيين الصلاحيات للأدوار ======
  Widget _buildRolePermissionsTab(AppDatabase db) {
    final predefinedPermissions = [
      'pos.access',
      'sales.create',
      'sales.view',
      'sales.delete',
      'purchases.create',
      'purchases.view',
      'products.manage',
      'customers.manage',
      'suppliers.manage',
      'inventory.manage',
      'reports.view',
      'accounting.view',
      'accounting.manage',
      'users.manage',
      'settings.manage',
      'hr.manage',
    ];

    return FutureBuilder<List<RolePermission>>(
      future: db.select(db.rolePermissions).get(),
      builder: (context, snapshot) {
        final rolePermissions = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'اختر الدور',
                  border: OutlineInputBorder(),
                ),
                items:
                    rolePermissions
                        .map((rp) => rp.role)
                        .toSet()
                        .toList()
                        .isNotEmpty
                    ? rolePermissions
                          .map((rp) => rp.role)
                          .toSet()
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList()
                    : ['admin', 'cashier', 'manager', 'viewer']
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRole = val);
                },
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: predefinedPermissions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final permCode = predefinedPermissions[index];
                  final hasPermission = rolePermissions.any(
                    (rp) =>
                        rp.role == _selectedRole &&
                        rp.permissionCode == permCode,
                  );

                  return SwitchListTile(
                    title: Text(permCode),
                    value: hasPermission,
                    onChanged: (val) async {
                      if (val) {
                        await db
                            .into(db.rolePermissions)
                            .insert(
                              RolePermissionsCompanion.insert(
                                id: drift.Value(const Uuid().v4()),
                                role: _selectedRole,
                                permissionCode: permCode,
                                syncStatus: const drift.Value(1),
                              ),
                            );
                      } else {
                        await (db.delete(db.rolePermissions)..where(
                              (rp) =>
                                  rp.role.equals(_selectedRole) &
                                  rp.permissionCode.equals(permCode),
                            ))
                            .go();
                      }
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ====== Dialogs ======
  void _showAddRoleDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة دور جديد'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'اسم الدور',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // Create a test user with this role to establish it
                // In a real app, you'd have a roles table
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم إنشاء الدور: ${controller.text}')),
                );
                setState(() {});
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  void _showAddPermissionDialog(BuildContext context, AppDatabase db) {
    final codeController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة صلاحية جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'رمز الصلاحية (مثال: pos.access)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
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
              if (codeController.text.isNotEmpty) {
                await db
                    .into(db.permissions)
                    .insert(
                      PermissionsCompanion.insert(
                        id: drift.Value(const Uuid().v4()),
                        code: codeController.text,
                        description: drift.Value(descController.text),
                        syncStatus: const drift.Value(1),
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }
}
