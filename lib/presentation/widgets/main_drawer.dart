import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/network/sync_service.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    const Color drawerBgColor = Color(0xFF1E1E26);
    const Color dividerColor = Color(0xFF3E3E4A);

    AuthProvider authProvider;
    SyncService syncService;
    AppLocalizations? l10n;

    try {
      authProvider = Provider.of<AuthProvider>(context, listen: false);
      syncService = Provider.of<SyncService>(context, listen: false);
      l10n = AppLocalizations.of(context);
    } catch (e) {
      return Drawer(
        backgroundColor: drawerBgColor,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white24, size: 40),
        ),
      );
    }

    final role = authProvider.currentUser?.role.toLowerCase() ?? 'cashier';
    final isAdmin = role == 'admin';
    final isManager = role == 'manager' || isAdmin;
    final isCashier = role == 'cashier' || isManager;

    return Drawer(
      width: 280,
      backgroundColor: drawerBgColor,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          _buildHeader(context, authProvider, drawerBgColor),
          const Divider(color: dividerColor, height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  title: l10n?.dashboard ?? 'لوحة التحكم',
                  onTap: () => context.go('/'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.point_of_sale_rounded,
                  title: l10n?.pos ?? 'نقطة البيع',
                  onTap: () => context.push('/pos'),
                ),
                if (isCashier) ...[
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_rounded,
                    title: l10n?.sales ?? 'سجل المبيعات',
                    onTap: () => context.push('/sales'),
                  ),
                  _buildExpansionGroup(
                    context,
                    icon: Icons.assignment_return_rounded,
                    title: l10n?.returns ?? 'المرتجعات',
                    children: [
                      _buildSubItem(context, l10n?.salesReturns ?? 'مرتجعات المبيعات', '/sales/returns'),
                      _buildSubItem(context, l10n?.purchaseReturns ?? 'مرتجعات المشتريات', '/purchases/returns'),
                    ],
                  ),
                ],
                if (isManager) ...[
                  const _DrawerDivider(),
                  _buildExpansionGroup(
                    context,
                    icon: Icons.inventory_2_rounded,
                    title: l10n?.products ?? 'المنتجات',
                    children: [
                      _buildSubItem(context, 'قائمة المنتجات', '/products'),
                      _buildSubItem(context, l10n?.categories ?? 'الفئات', '/categories'),
                      _buildSubItem(context, 'المنتجات أوشكت على النفاد', '/low-stock'),
                    ],
                  ),
                  _buildExpansionGroup(
                    context,
                    icon: Icons.shopping_cart_rounded,
                    title: l10n?.purchases ?? 'المشتريات',
                    children: [
                       _buildSubItem(context, 'قائمة المشتريات', '/purchases'),
                       _buildSubItem(context, 'إضافة عملية شراء', '/purchases/new'),
                    ]
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.swap_horiz_rounded,
                    title: 'التحويل المخزني',
                    onTap: () => context.push('/inventory/transfer'),
                  ),
                ],

                const _DrawerDivider(),

                _buildExpansionGroup(
                  context,
                  icon: Icons.people_alt_rounded,
                  title: l10n?.customers ?? 'العملاء',
                  children: [
                    _buildSubItem(context, 'قائمة العملاء', '/customers'),
                    // تم توجيه "كشوفات الحساب" إلى صفحة العملاء حيث يمكن اختيار العميل لاستعراض كشفه
                    _buildSubItem(context, 'كشوفات حساب العملاء', '/customers'),
                  ]
                ),

                if (isManager) ...[
                   _buildExpansionGroup(
                    context,
                    icon: Icons.local_shipping_rounded,
                    title: l10n?.suppliers ?? 'الموردين',
                    children: [
                      _buildSubItem(context, 'قائمة الموردين', '/suppliers'),
                      // تم توجيه "كشوفات الحساب" إلى صفحة الموردين
                      _buildSubItem(context, 'كشوفات حساب الموردين', '/suppliers'),
                    ]
                  ),
                ],
                if (isManager) ...[
                  const _DrawerDivider(),
                  _buildExpansionGroup(
                    context,
                    icon: Icons.badge_rounded,
                    title: 'الموارد البشرية',
                    children: [
                      _buildSubItem(context, 'إدارة الموظفين', '/hr/employees'),
                      _buildSubItem(context, 'مسيرات الرواتب', '/hr/payroll'),
                    ],
                  ),
                  _buildExpansionGroup(
                    context,
                    icon: Icons.assessment_rounded,
                    title: 'التقارير',
                    children: [
                      _buildSubItem(context, 'تقارير المبيعات', '/reports/sales'),
                      _buildSubItem(context, 'ربحية المنتجات', '/reports/profitability'),
                      _buildSubItem(context, 'تقارير المخزون', '/reports/inventory'),
                      _buildSubItem(context, 'تقرير ضريبة القيمة المضافة', '/reports/vat'),
                      _buildSubItem(context, 'سجل التدقيق', '/reports/audit'),
                    ],
                  ),
                ],
                if (isAdmin) ...[
                  const _DrawerDivider(),
                  _buildExpansionGroup(
                    context,
                    icon: Icons.account_balance_rounded,
                    title: l10n?.accounting ?? 'المحاسبة',
                    children: [
                      _buildSubItem(context, l10n?.chartOfAccounts ?? 'شجرة الحسابات', '/accounting/coa'),
                      _buildSubItem(context, l10n?.generalLedger ?? 'دفتر الأستاذ', '/accounting/general-ledger'),
                      _buildSubItem(context, 'الميزانية العمومية', '/accounting/balance-sheet'),
                      _buildSubItem(context, 'قائمة الدخل', '/accounting/income-statement'),
                      _buildSubItem(context, 'ميزان المراجعة', '/accounting/trial-balance'),
                       _buildSubItem(context, 'المصروفات', '/accounting/expenses'),
                       _buildSubItem(context, 'الأصول الثابتة', '/accounting/fixed-assets'),
                       _buildSubItem(context, 'قيود يدوية', '/accounting/manual-journal'),
                       _buildSubItem(context, 'التسويات', '/accounting/reconciliation'),
                       _buildSubItem(context, 'ورديات الكاشير', '/accounting/shifts'),
                       _buildSubItem(context, 'مراكز التكلفة', '/accounting/cost-centers'),
                    ],
                  ),
                   _buildExpansionGroup(
                     context,
                     icon: Icons.settings_rounded,
                     title: 'الإعدادات',
                     children: [
                       _buildSubItem(context, 'إدارة المستخدمين', '/users'),
                       _buildSubItem(context, 'النسخ الاحتياطي', '/settings/backup'),
                       _buildSubItem(context, 'المزامنة', '/sync'),
                       _buildSubItem(context, 'إعدادات الطابعة', '/settings/printer'),
                     ]
                   )
                ],

                const SizedBox(height: 20),
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
          _buildSyncStatus(context, syncService),
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
        style: const TextStyle(color: Colors.white60, fontSize: 14),
      ),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }

  Widget _buildSyncStatus(BuildContext context, SyncService? syncService) {
    if (syncService == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: syncService.isSyncing,
      builder: (context, isSyncing, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          color: Colors.black12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                isSyncing ? 'جاري المزامنة...' : 'تمت المزامنة',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(width: 8),
              Icon(
                isSyncing ? Icons.sync : Icons.cloud_done,
                color: isSyncing ? Colors.blue : Colors.green,
                size: 12,
              ),
            ],
          ),
        );
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
