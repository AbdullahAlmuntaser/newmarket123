import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/widgets/navigation/command_palette.dart';

import 'package:supermarket/core/auth/user_role.dart';
import 'package:supermarket/core/auth/access_guard.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    const Color drawerBgColor = Color(0xFF1E1E26);
    const Color dividerColor = Color(0xFF3E3E4A);

    AuthProvider authProvider;
    AppLocalizations? l10n;

    try {
      authProvider = Provider.of<AuthProvider>(context, listen: false);
      l10n = AppLocalizations.of(context);
    } catch (e) {
      return const Drawer(
        backgroundColor: drawerBgColor,
        child: Center(
          child: Icon(Icons.error_outline, color: Colors.white24, size: 40),
        ),
      );
    }

    final role =
        UserRole.fromString(authProvider.currentUser?.role ?? 'cashier');

    return Drawer(
      width: 280,
      backgroundColor: drawerBgColor,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          _buildHeader(context, authProvider, drawerBgColor),
          const Divider(color: dividerColor, height: 1),
          // Search Entry Point
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => const CommandPalette(),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D38),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dividerColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.white38, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'بحث سريع... (Ctrl+K)',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  title: l10n?.dashboard ?? 'لوحة التحكم الرئيسي',
                  onTap: () => context.go('/'),
                ),
                const _DrawerDivider(),

                // WORKSPACES
                if (AccessGuard.canAccess('/workspace/operations', role))
                  _buildExpansionGroup(
                    context,
                    icon: Icons.settings_input_component_rounded,
                    title: 'مساحة عمل العمليات',
                    children: [
                      _buildSubItem(
                          context, 'نظرة عامة', '/workspace/operations'),
                      _buildSubItem(context, 'نقطة البيع (POS)', '/pos'),
                      _buildSubItem(context, 'سجل المبيعات', '/sales'),
                      _buildSubItem(context, 'فواتير الشراء', '/purchases'),
                      _buildSubItem(
                          context, 'مرتجعات المبيعات', '/sales/returns'),
                      _buildSubItem(
                          context, 'مرتجعات المشتريات', '/purchases/returns'),
                    ],
                  ),

                if (AccessGuard.canAccess('/workspace/accounting', role))
                  _buildExpansionGroup(
                    context,
                    icon: Icons.account_balance_rounded,
                    title: 'مساحة عمل الحسابات',
                    children: [
                      _buildSubItem(
                          context, 'نظرة عامة', '/workspace/accounting'),
                      _buildSubItem(
                          context, 'شجرة الحسابات', '/accounting/coa'),
                      _buildSubItem(context, 'دفتر الأستاذ',
                          '/accounting/general-ledger'),
                      _buildSubItem(context, 'الميزانية العمومية',
                          '/accounting/balance-sheet'),
                      _buildSubItem(context, 'قائمة الدخل',
                          '/accounting/income-statement'),
                      _buildSubItem(context, 'سندات القبض والصرف',
                          '/accounting/manual-voucher'),
                      _buildSubItem(context, 'القيود اليدوية',
                          '/accounting/manual-journal'),
                      _buildSubItem(context, 'الصندوق',
                          '/accounting/cashbox'),
                      _buildSubItem(context, 'إدارة الورديات',
                          '/accounting/shifts'),
                    ],
                  ),

                if (AccessGuard.canAccess('/workspace/inventory', role))
                  _buildExpansionGroup(
                    context,
                    icon: Icons.inventory_2_rounded,
                    title: 'مساحة عمل المخزون',
                    children: [
                      _buildSubItem(
                          context, 'نظرة عامة', '/workspace/inventory'),
                      _buildSubItem(context, 'قائمة المنتجات', '/products'),
                      _buildSubItem(
                          context, 'المستودعات', '/inventory/warehouses'),
                      _buildSubItem(
                          context, 'جرد المخزون', '/inventory/stock-take'),
                      _buildSubItem(
                          context, 'التحويل المخزني', '/inventory/transfer'),
                      _buildSubItem(
                          context, 'إدارة التصنيع', '/manufacturing/bom'),
                      _buildSubItem(
                          context, 'تقرير الورديات', '/inventory/shifts'),
                    ],
                  ),

                if (AccessGuard.canAccess('/workspace/parties', role))
                  _buildExpansionGroup(
                    context,
                    icon: Icons.people_alt_rounded,
                    title: 'مساحة عمل الأطراف',
                    children: [
                      _buildSubItem(context, 'نظرة عامة', '/workspace/parties'),
                      _buildSubItem(context, 'قائمة العملاء', '/customers'),
                      _buildSubItem(context, 'قائمة الموردين', '/suppliers'),
                      _buildSubItem(context, 'إدارة الموظفين', '/hr/employees'),
                      _buildSubItem(context, 'إدارة المستخدمين', '/users'),
                    ],
                  ),

                if (AccessGuard.canAccess('/workspace/reports', role))
                  _buildExpansionGroup(
                    context,
                    icon: Icons.assessment_rounded,
                    title: 'مساحة عمل التقارير',
                    children: [
                      _buildSubItem(context, 'نظرة عامة', '/workspace/reports'),
                      _buildSubItem(
                          context, 'تقارير المبيعات', '/reports/sales'),
                      _buildSubItem(
                          context, 'تقارير المخزون', '/reports/inventory'),
                      _buildSubItem(
                          context, 'تقرير القيمة المضافة', '/reports/vat'),
                      _buildSubItem(context, 'سجل التدقيق', '/reports/audit'),
                    ],
                  ),

                if (AccessGuard.canAccess('/workspace/admin', role))
                  _buildExpansionGroup(
                    context,
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'مساحة عمل الإدارة',
                    children: [
                      _buildSubItem(context, 'نظرة عامة', '/workspace/admin'),
                      _buildSubItem(
                          context, 'إعدادات النظام', '/settings/system'),
                      _buildSubItem(
                          context, 'أسعار صرف العملات', '/settings/currency-rates'),
                      _buildSubItem(
                          context, 'الصلاحيات', '/settings/permissions'),
                      _buildSubItem(
                          context, 'النسخ الاحتياطي', '/settings/backup'),
                      _buildSubItem(context, 'سير الموافقات', '/approvals'),
                    ],
                  ),

                const _DrawerDivider(),
                _buildDrawerItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: l10n?.logout ?? 'تسجيل الخروج',
                  onTap: () {
                    authProvider.logout();
                    context.go('/login');
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthProvider authProvider,
    Color bgColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person_rounded,
              size: 45,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            authProvider.currentUser?.fullName ?? 'System Admin',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            authProvider.currentUser?.role ?? 'admin',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.white70,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      visualDensity: const VisualDensity(vertical: -1),
    );
  }

  Widget _buildExpansionGroup(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.white70, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        children: children,
      ),
    );
  }

  Widget _buildSubItem(BuildContext context, String title, String route) {
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 55, left: 16),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: Color(0xFF3E3E4A),
      height: 20,
      thickness: 1,
      indent: 15,
      endIndent: 15,
    );
  }
}
