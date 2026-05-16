import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class PermissionsManagementPage extends StatefulWidget {
  const PermissionsManagementPage({super.key});

  @override
  State<PermissionsManagementPage> createState() => _PermissionsManagementPageState();
}

class _PermissionsManagementPageState extends State<PermissionsManagementPage> {
  final List<String> _roles = ['Admin', 'Manager', 'Cashier', 'User'];
  final Map<String, List<PermissionItem>> _rolePermissions = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final db = Provider.of<AppDatabase>(context, listen: false);

    for (var role in _roles) {
      final permissions = await (db.select(db.rolePermissions)
            ..where((rp) => rp.role.equals(role)))
          .get();

      setState(() {
        _rolePermissions[role] = _allPermissions.map((p) {
          final hasPermission = permissions.any((perm) => perm.permissionCode == p.code);
          return PermissionItem(
            code: p.code,
            name: p.name,
            nameAr: p.nameAr,
            granted: hasPermission,
          );
        }).toList();
      });
    }
  }

  Future<void> _togglePermission(String role, String permissionCode, bool granted) async {
    final db = Provider.of<AppDatabase>(context, listen: false);

    if (granted) {
      await db.into(db.rolePermissions).insert(
        RolePermissionsCompanion.insert(
          role: role,
          permissionCode: permissionCode,
        ),
      );
    } else {
      await (db.delete(db.rolePermissions)
            ..where((rp) => rp.role.equals(role) & rp.permissionCode.equals(permissionCode)))
          .go();
    }

    await _loadPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصلاحيات'),
      ),
      body: _rolePermissions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                return ExpansionTile(
                  title: Text(_getRoleDisplayName(role, l10n)),
                  leading: Icon(_getRoleIcon(role)),
                  children: (_rolePermissions[role] ?? []).map((permission) {
                    return CheckboxListTile(
                      title: Text(l10n.localeName == 'ar' ? permission.nameAr : permission.name),
                      subtitle: Text(permission.code),
                      value: permission.granted,
                      onChanged: (value) => _togglePermission(role, permission.code, value ?? false),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }

  String _getRoleDisplayName(String role, AppLocalizations l10n) {
    switch (role) {
      case 'Admin':
        return 'مدير النظام';
      case 'Manager':
        return 'مدير';
      case 'Cashier':
        return 'كاشير';
      case 'User':
        return 'مستخدم';
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Admin':
        return Icons.admin_panel_settings;
      case 'Manager':
        return Icons.supervisor_account;
      case 'Cashier':
        return Icons.point_of_sale;
      case 'User':
        return Icons.person;
      default:
        return Icons.person;
    }
  }
}

class PermissionItem {
  final String code;
  final String name;
  final String nameAr;
  final bool granted;

  PermissionItem({
    required this.code,
    required this.name,
    required this.nameAr,
    required this.granted,
  });
}

class PermissionDefinition {
  final String code;
  final String name;
  final String nameAr;
  final String category;

  PermissionDefinition({
    required this.code,
    required this.name,
    required this.nameAr,
    required this.category,
  });
}

final List<PermissionDefinition> _allPermissions = [
  PermissionDefinition(code: 'POST_SALE', name: 'Post Sales', nameAr: 'نشر المبيعات', category: 'Sales'),
  PermissionDefinition(code: 'POST_PURCHASE', name: 'Post Purchases', nameAr: 'نشر المشتريات', category: 'Purchases'),
  PermissionDefinition(code: 'POST_SALE_RETURN', name: 'Post Sales Returns', nameAr: 'نشر مرتجعات المبيعات', category: 'Returns'),
  PermissionDefinition(code: 'POST_PURCHASE_RETURN', name: 'Post Purchase Returns', nameAr: 'نشر مرتجعات المشتريات', category: 'Returns'),
  PermissionDefinition(code: 'DELETE_INVOICE', name: 'Delete Invoices', nameAr: 'حذف الفواتير', category: 'Admin'),
  PermissionDefinition(code: 'VOID_TRANSACTION', name: 'Void Transactions', nameAr: 'إلغاء المعاملات', category: 'Admin'),
  PermissionDefinition(code: 'MANAGE_USERS', name: 'Manage Users', nameAr: 'إدارة المستخدمين', category: 'Admin'),
  PermissionDefinition(code: 'VIEW_REPORTS', name: 'View Reports', nameAr: 'عرض التقارير', category: 'Reports'),
  PermissionDefinition(code: 'MANAGE_SETTINGS', name: 'Manage Settings', nameAr: 'إدارة الإعدادات', category: 'Settings'),
  PermissionDefinition(code: 'MANAGE_INVENTORY', name: 'Manage Inventory', nameAr: 'إدارة المخزون', category: 'Inventory'),
  PermissionDefinition(code: 'APPROVE_DISCOUNT', name: 'Approve Discounts', nameAr: 'الموافقة على الخصومات', category: 'Sales'),
  PermissionDefinition(code: 'MANAGE_CUSTOMERS', name: 'Manage Customers', nameAr: 'إدارة العملاء', category: 'Customers'),
  PermissionDefinition(code: 'MANAGE_SUPPLIERS', name: 'Manage Suppliers', nameAr: 'إدارة الموردين', category: 'Suppliers'),
  PermissionDefinition(code: 'VIEW_FINANCIALS', name: 'View Financials', nameAr: 'عرض البيانات المالية', category: 'Accounting'),
  PermissionDefinition(code: 'MANAGE_ACCOUNTS', name: 'Manage Accounts', nameAr: 'إدارة الحسابات', category: 'Accounting'),
];