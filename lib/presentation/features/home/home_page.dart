import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/core/services/fast_access_service.dart';
import 'package:supermarket/core/services/dashboard_service.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/auth/user_role.dart';
import 'package:supermarket/core/auth/access_guard.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/widgets/notification_tray.dart';
import 'package:supermarket/presentation/features/dashboard/widgets/dynamic_dashboard.dart';
import 'package:supermarket/presentation/widgets/navigation/command_palette.dart';
import 'package:supermarket/presentation/features/workspaces/workspace_base.dart';
import 'package:supermarket/presentation/widgets/shared/skeleton_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final fastAccess = Provider.of<FastAccessService>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final role = UserRole.fromString(authProvider.currentUser?.role ?? 'cashier');
    final dashboardService = Provider.of<DashboardService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace ERP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'البحث السريع (Ctrl+K)',
            onPressed: () => showDialog(
              context: context,
              builder: (context) => const CommandPalette(),
            ),
          ),
          Builder(
            builder: (scaffoldContext) {
              final unreadCount = context.select<NotificationService, int>(
                (service) => service.unreadCount,
              );
              return IconButton(
                icon: Badge.count(
                  count: unreadCount,
                  isLabelVisible: unreadCount > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Scaffold.of(scaffoldContext).openEndDrawer(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const MainDrawer(),
      endDrawer: const NotificationTray(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await dashboardService.getStats();
        },
        child: FutureBuilder<DashboardStats>(
          future: dashboardService.getStats(),
          builder: (context, snapshot) {
            final isLoading = !snapshot.hasData;
            final stats = snapshot.data;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoading)
                        _buildKPISkeleton()
                      else
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: _buildKPISection(context, stats!),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                      _buildActionCenter(context, stats, isLoading),
                      const SizedBox(height: 32),
                      const Text(
                        'Workspaces الرئيسية',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildWorkspacesGrid(context, role, stats),
                      const SizedBox(height: 32),
                      const Text(
                        'الإجراءات السريعة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildQuickActionsGrid(context, role),
                      const SizedBox(height: 32),
                      if (fastAccess.recentRoutes.isNotEmpty) ...[
                        const Text(
                          'شاشات تم فتحها مؤخراً',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildRecentRoutes(fastAccess),
                        const SizedBox(height: 32),
                      ],
                      const Text(
                        'نظرة عامة على الأداء',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const DynamicDashboard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) context.go('/');
          if (index == 1) context.push('/pos');
          if (index == 2) {
            showDialog(
              context: context,
              builder: (context) => const CommandPalette(),
            );
          }
          if (index == 3) {
            final scaffold = Scaffold.of(context);
            if (scaffold.hasDrawer) {
              scaffold.openDrawer();
            }
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'POS'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'بحث'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'القائمة'),
        ],
      ),
    );
  }

  Widget _buildKPISkeleton() {
    return const Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SkeletonLoader(width: 250, height: 80),
        SkeletonLoader(width: 250, height: 80),
        SkeletonLoader(width: 250, height: 80),
      ],
    );
  }

  Widget _buildKPISection(BuildContext context, DashboardStats stats) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildKPICard(context, 'المبيعات اليومية', '${stats.todaySales.toStringAsFixed(2)} ر.س', Icons.trending_up, Colors.green),
        _buildKPICard(context, 'رصيد الصندوق', '${stats.currentCash.toStringAsFixed(2)} ر.س', Icons.account_balance_wallet, Colors.teal),
        _buildKPICard(context, 'تنبيهات المخزون', stats.lowStockCount.toInt().toString(), Icons.warning_amber_rounded, Colors.red),
      ],
    );
  }

  Widget _buildKPICard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCenter(BuildContext context, DashboardStats? stats, bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow[700]!.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.yellow[800]),
              const SizedBox(width: 8),
              const Text(
                'مركز الإجراءات (Action Center)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const SkeletonLoader(height: 40)
          else ...[
            if (stats!.lowStockCount > 0)
              _buildActionItem(
                context,
                'تنبيه مخزون: هناك ${stats.lowStockCount.toInt()} أصناف قاربت على الانتهاء',
                Icons.inventory_2_outlined,
                Colors.red,
                () => context.push('/low-stock'),
              ),
            _buildActionItem(
              context,
              'هناك 3 طلبات شراء بانتظار الموافقة',
              Icons.approval_rounded,
              Colors.orange,
              () => context.push('/approvals'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, String text, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
            const Icon(Icons.chevron_left, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspacesGrid(BuildContext context, UserRole role, DashboardStats? stats) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        if (AccessGuard.canAccess('/workspace/operations', role))
          WorkspaceTile(
            title: 'العمليات',
            icon: Icons.settings_input_component_rounded,
            color: Colors.blue,
            subtitle: 'المبيعات والمشتريات',
            onTap: () => context.push('/workspace/operations'),
          ),
        if (AccessGuard.canAccess('/workspace/accounting', role))
          WorkspaceTile(
            title: 'الحسابات',
            icon: Icons.account_balance_rounded,
            color: Colors.purple,
            subtitle: 'القيود والتقارير المالية',
            onTap: () => context.push('/workspace/accounting'),
          ),
        if (AccessGuard.canAccess('/workspace/inventory', role))
          WorkspaceTile(
            title: 'المخزون',
            icon: Icons.inventory_2_rounded,
            color: Colors.brown,
            subtitle: 'المنتجات والمستودعات',
            badgeValue: stats?.lowStockCount.toInt().toString(),
            onTap: () => context.push('/workspace/inventory'),
          ),
        if (AccessGuard.canAccess('/workspace/parties', role))
          WorkspaceTile(
            title: 'الأطراف',
            icon: Icons.people_alt_rounded,
            color: Colors.teal,
            subtitle: 'العملاء والموردين والموظفين',
            onTap: () => context.push('/workspace/parties'),
          ),
        if (AccessGuard.canAccess('/workspace/reports', role))
          WorkspaceTile(
            title: 'التقارير',
            icon: Icons.assessment_rounded,
            color: Colors.indigo,
            subtitle: 'تحليلات الأداء والبيانات',
            onTap: () => context.push('/workspace/reports'),
          ),
        if (AccessGuard.canAccess('/workspace/admin', role))
          WorkspaceTile(
            title: 'الإدارة',
            icon: Icons.admin_panel_settings_rounded,
            color: Colors.blueGrey,
            subtitle: 'إعدادات النظام والأمن',
            onTap: () => context.push('/workspace/admin'),
          ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, UserRole role) {
    final List<Widget> actions = [];
    _addActionIfAllowed(actions, context, role, '/pos', Icons.point_of_sale, 'بيع جديد', Colors.green);
    _addActionIfAllowed(actions, context, role, '/purchases/new', Icons.add_shopping_cart, 'شراء جديد', Colors.blue);
    _addActionIfAllowed(actions, context, role, '/accounting/manual-voucher?receipt=true', Icons.add_card_rounded, 'سند قبض', Colors.teal);
    _addActionIfAllowed(actions, context, role, '/accounting/manual-voucher?receipt=false', Icons.remove_circle_outline_rounded, 'سند صرف', Colors.redAccent);
    _addActionIfAllowed(actions, context, role, '/customers', Icons.person_add_rounded, 'إضافة عميل', Colors.orange);
    _addActionIfAllowed(actions, context, role, '/products', Icons.add_box_rounded, 'إضافة منتج', Colors.brown);
    return Wrap(spacing: 16, runSpacing: 16, children: actions);
  }

  void _addActionIfAllowed(List<Widget> list, BuildContext context, UserRole role, String route, IconData icon, String label, Color color) {
    if (AccessGuard.canAccess(route.split('?').first, role)) {
      list.add(_QuickActionButton(onPressed: () => context.push(route), icon: icon, label: label, color: color));
    }
  }

  Widget _buildRecentRoutes(FastAccessService fastAccess) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fastAccess.recentRoutes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final route = fastAccess.recentRoutes[index];
          final item = fastAccess.items.firstWhere((i) => i.route == route, orElse: () => FastAccessItem(title: route, route: route, icon: Icons.link, category: ''));
          return ActionChip(avatar: Icon(item.icon, size: 16), label: Text(item.title), onPressed: () => context.push(route));
        },
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;
  const _QuickActionButton({required this.onPressed, required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]),
      ),
    );
  }
}
