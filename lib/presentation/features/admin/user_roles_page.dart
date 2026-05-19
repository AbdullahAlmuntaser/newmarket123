import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class UserRolesPage extends StatefulWidget {
  const UserRolesPage({super.key});

  @override
  State<UserRolesPage> createState() => _UserRolesPageState();
}

class _UserRolesPageState extends State<UserRolesPage> {
  final List<String> _roles = ['Admin', 'Manager', 'Cashier', 'Accountant'];
  
  final Map<String, List<String>> _rolePermissions = {
    'Admin': [
      'POST_SALE', 'POST_PURCHASE', 'POST_SALE_RETURN', 'POST_PURCHASE_RETURN',
      'DELETE_INVOICE', 'VOID_TRANSACTION', 'MANAGE_USERS', 'VIEW_REPORTS',
      'MANAGE_SETTINGS', 'MANAGE_INVENTORY', 'APPROVE_DISCOUNT', 'EDIT_TAX',
    ],
    'Manager': [
      'POST_SALE', 'POST_PURCHASE', 'POST_SALE_RETURN', 'POST_PURCHASE_RETURN',
      'VIEW_REPORTS', 'MANAGE_INVENTORY', 'APPROVE_DISCOUNT',
    ],
    'Cashier': [
      'POST_SALE', 'POST_SALE_RETURN',
    ],
    'Accountant': [
      'POST_PURCHASE', 'VIEW_REPORTS', 'MANAGE_INVENTORY',
    ],
  };

  String _selectedRole = 'Admin';

  @override
  void initState() {
    super.initState();
    _loadPermissionsForRole(_selectedRole);
  }

  Future<void> _loadPermissionsForRole(String role) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final existingPermissions = await (db.select(db.rolePermissions)
      ..where((rp) => rp.role.equals(role)))
      .get();

    final currentCodes = existingPermissions.map((p) => p.permissionCode).toSet();
    
    setState(() {
      _rolePermissions[role] = currentCodes.toList();
    });
  }

  Future<void> _togglePermission(String permissionCode, bool enabled) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    if (enabled) {
      await db.into(db.rolePermissions).insert(
        RolePermissionsCompanion.insert(
          role: _selectedRole,
          permissionCode: permissionCode,
        ),
      );
    } else {
      await (db.delete(db.rolePermissions)
        ..where((rp) => 
            rp.role.equals(_selectedRole) & 
            rp.permissionCode.equals(permissionCode)))
        .go();
    }
    
    setState(() {
      if (enabled) {
        _rolePermissions[_selectedRole] = [
          ..._rolePermissions[_selectedRole] ?? [],
          permissionCode,
        ];
      } else {
        _rolePermissions[_selectedRole] = 
            (_rolePermissions[_selectedRole] ?? []).where((p) => p != permissionCode).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userRoles),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: l10n.role,
                border: const OutlineInputBorder(),
              ),
              items: _roles.map((role) => DropdownMenuItem(
                value: role,
                child: Text(role),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                  _loadPermissionsForRole(value);
                }
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSectionTitle(l10n.userRoles),
                ..._buildPermissionCheckboxes(),
                const Divider(),
                _buildSectionTitle(l10n.staffManagement),
                _buildUserManagement(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildPermissionCheckboxes() {
    final allPermissions = [
      {'code': 'POST_SALE', 'label': 'إنشاء مبيعات'},
      {'code': 'POST_PURCHASE', 'label': 'إنشاء مشتريات'},
      {'code': 'POST_SALE_RETURN', 'label': 'مرتجع مبيعات'},
      {'code': 'POST_PURCHASE_RETURN', 'label': 'مرتجع مشتريات'},
      {'code': 'DELETE_INVOICE', 'label': 'حذف فاتورة'},
      {'code': 'VOID_TRANSACTION', 'label': 'إلغاء عملية'},
      {'code': 'MANAGE_USERS', 'label': 'إدارة المستخدمين'},
      {'code': 'VIEW_REPORTS', 'label': 'عرض التقارير'},
      {'code': 'MANAGE_SETTINGS', 'label': 'إدارة الإعدادات'},
      {'code': 'MANAGE_INVENTORY', 'label': 'إدارة المخزون'},
      {'code': 'APPROVE_DISCOUNT', 'label': 'الموافقة على خصم'},
      {'code': 'EDIT_TAX', 'label': 'تعديل الضريبة'},
    ];

    final currentPermissions = _rolePermissions[_selectedRole] ?? [];
    
    return allPermissions.map((perm) => CheckboxListTile(
      title: Text(perm['label']!),
      subtitle: Text(perm['code']!),
      value: currentPermissions.contains(perm['code']),
      onChanged: (value) => _togglePermission(perm['code']!, value ?? false),
    )).toList();
  }

  Widget _buildUserManagement() {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    return StreamBuilder<List<User>>(
      stream: db.select(db.users).watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final users = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('عدد المستخدمين: ${users.length}'),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUserDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة مستخدم'),
                  ),
                ],
              ),
            ),
            ...users.map((user) => ListTile(
              leading: CircleAvatar(
                child: Text(user.role[0]),
              ),
              title: Text(user.fullName),
              subtitle: Text('${user.role} - ${user.username}'),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('تعديل'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteUser(user);
                  }
                },
              ),
            )),
          ],
        );
      },
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    String selectedRole = 'Cashier';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: _roles.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r),
                )).toList(),
                onChanged: (value) => selectedRole = value ?? 'Cashier',
                decoration: const InputDecoration(labelText: 'الدور'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
                return;
              }
              
              final db = Provider.of<AppDatabase>(context, listen: false);
              final navigator = Navigator.of(context);
              await db.into(db.users).insert(
                UsersCompanion.insert(
                  username: usernameController.text,
                  password: passwordController.text,
                  role: selectedRole,
                  fullName: fullNameController.text.isEmpty 
                      ? usernameController.text 
                      : fullNameController.text,
                ),
              );
              
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المستخدم ${user.username}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final db = Provider.of<AppDatabase>(context, listen: false);
      await (db.delete(db.users)..where((u) => u.id.equals(user.id))).go();
    }
  }
}