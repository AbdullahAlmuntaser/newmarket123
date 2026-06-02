import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/core/services/fast_access_service.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/widgets/notification_tray.dart';
import 'package:supermarket/presentation/features/dashboard/widgets/dynamic_dashboard.dart';
import 'package:supermarket/presentation/widgets/navigation/command_palette.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fastAccess = Provider.of<FastAccessService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.home),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.overview,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const DynamicDashboard(),
            if (fastAccess.recentRoutes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'شاشات تم فتحها مؤخراً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fastAccess.recentRoutes.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final route = fastAccess.recentRoutes[index];
                    final item = fastAccess.items.firstWhere(
                      (i) => i.route == route,
                      orElse: () => FastAccessItem(
                        title: route,
                        route: route,
                        icon: Icons.link,
                        category: '',
                      ),
                    );
                    return ActionChip(
                      avatar: Icon(item.icon, size: 16),
                      label: Text(item.title),
                      onPressed: () => context.push(route),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              l10n.quickActions,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildQuickActions(context, l10n),
            const SizedBox(height: 24),
          ],
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

  Widget _buildQuickActions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _QuickActionButton(
          onPressed: () => context.push('/pos'),
          icon: Icons.point_of_sale,
          label: l10n.newSale,
          color: Colors.green,
        ),
        _QuickActionButton(
          onPressed: () => context.push('/purchases/new'),
          icon: Icons.add_shopping_cart,
          label: l10n.newPurchaseInvoice,
          color: Colors.blue,
        ),
        _QuickActionButton(
          onPressed: () => context.push('/sales/returns'),
          icon: Icons.assignment_return,
          label: l10n.salesReturns,
          color: Colors.orange,
        ),
        _QuickActionButton(
          onPressed: () => context.push('/accounting/coa'),
          icon: Icons.account_tree,
          label: 'شجرة الحسابات',
          color: Colors.purple,
        ),
        _QuickActionButton(
          onPressed: () => context.push('/reports/sales'),
          icon: Icons.bar_chart,
          label: 'تقارير المبيعات',
          color: Colors.teal,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _QuickActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
