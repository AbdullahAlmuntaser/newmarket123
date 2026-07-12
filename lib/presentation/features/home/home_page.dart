import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/auth/user_role.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/widgets/notification_tray.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';
import 'package:supermarket/presentation/features/home/widgets/command_center_header.dart';
import 'package:supermarket/presentation/features/home/widgets/new_operation_sheet.dart';
import 'package:supermarket/presentation/features/home/widgets/todays_business_section.dart';
import 'package:supermarket/presentation/features/home/widgets/floating_quick_actions.dart';
import 'package:supermarket/presentation/features/home/widgets/quick_access_section.dart';
import 'package:supermarket/presentation/features/home/widgets/favorites_section.dart';
import 'package:supermarket/presentation/features/home/widgets/attention_center_section.dart';
import 'package:supermarket/presentation/features/home/widgets/activity_timeline_section.dart';
import 'package:supermarket/presentation/features/home/widgets/dashboard_section_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommandCenterProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandCenterProvider>();
    final auth = context.read<AuthProvider>();
    final role = UserRole.fromString(auth.currentUser?.role ?? 'cashier');
    final userId = auth.currentUser?.id ?? 'default';

    return Scaffold(
      appBar: _buildAppBar(context, role),
      drawer: const MainDrawer(),
      endDrawer: const NotificationTray(),
      body: provider.isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: () => provider.loadDashboard(),
              child: _buildBody(context, provider, role, userId),
            ),
      floatingActionButton: const FloatingQuickActions(),
      bottomNavigationBar: _buildBottomNav(context, role),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserRole role) {
    return AppBar(
      title: const Text('ERP Command Center',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      actions: [
        IconButton(
          icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
          tooltip: 'تخصيص الداشبورد',
          onPressed: () => DashboardSectionConfig.show(context),
        ),
        Builder(
          builder: (ctx) {
            final unread =
                context.select<NotificationService, int>((s) => s.unreadCount);
            return IconButton(
              icon: Badge.count(
                count: unread,
                isLabelVisible: unread > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(BuildContext context, CommandCenterProvider provider,
      UserRole role, String userId) {
    final visibleSections =
        provider.sections.where((s) => s.isVisible).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.md, AppDimensions.md, AppDimensions.md, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Global Smart Search ───
              const CommandCenterHeader(),
              const SizedBox(height: AppDimensions.lg),

              // ─── New Operation Button ───
              _buildNewOperationBanner(context),
              const SizedBox(height: AppDimensions.lg),

              // ─── Dynamic Sections ───
              for (final section in visibleSections) ...[
                _buildSection(context, section.id, provider, role, userId),
                const SizedBox(height: AppDimensions.xl),
              ],

              // ─── Workspace Grid (preserved from original) ───
              _buildWorkspacesSection(context, role),
              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String sectionId,
      CommandCenterProvider provider, UserRole role, String userId) {
    switch (sectionId) {
      case 'today':
        return const TodaysBusinessSection();
      case 'attention':
        return const AttentionCenterSection();
      case 'operations':
        return _buildQuickOperations(context, role);
      case 'favorites':
        return const FavoritesSection();
      case 'quick_access':
        return const QuickAccessSection();
      case 'timeline':
        return const ActivityTimelineSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNewOperationBanner(BuildContext context) {
    return InkWell(
      onTap: () => NewOperationSheet.show(context),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg, vertical: AppDimensions.md),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
            SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إنشاء عملية جديدة',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('بيع، شراء، مرتجع، سند، أو أي عملية أخرى',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOperations(BuildContext context, UserRole role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on, size: 20, color: AppColors.warning),
            SizedBox(width: AppDimensions.sm),
            Text('عمليات سريعة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: [
            _buildQuickOpChip(context, 'بيع', Icons.point_of_sale,
                AppColors.opSales, '/pos', role),
            _buildQuickOpChip(context, 'شراء', Icons.shopping_bag,
                AppColors.opPurchases, '/purchases/new', role),
            _buildQuickOpChip(
                context,
                'سند قبض',
                Icons.receipt,
                AppColors.opCashbox,
                '/accounting/manual-voucher?receipt=true',
                role),
            _buildQuickOpChip(
                context,
                'سند صرف',
                Icons.payment,
                AppColors.error,
                '/accounting/manual-voucher?receipt=false',
                role),
            _buildQuickOpChip(context, 'عميل', Icons.person_add,
                AppColors.opCustomers, '/customers', role),
            _buildQuickOpChip(context, 'منتج', Icons.add_box,
                AppColors.opInventory, '/products', role),
            _buildQuickOpChip(context, 'مورد', Icons.local_shipping,
                AppColors.opSuppliers, '/suppliers', role),
            _buildQuickOpChip(context, 'تقرير', Icons.assessment,
                AppColors.opReports, '/reports/sales', role),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickOpChip(BuildContext context, String label, IconData icon,
      Color color, String route, UserRole role) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: color.withOpacity(0.05),
      side: BorderSide(color: color.withOpacity(0.2)),
      onPressed: () => context.push(route),
    );
  }

  Widget _buildWorkspacesSection(BuildContext context, UserRole role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الأقسام الرئيسية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppDimensions.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 2;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppDimensions.sm,
              crossAxisSpacing: AppDimensions.sm,
              childAspectRatio: 3,
              children: [
                _buildWorkspaceTile(
                    context,
                    'العمليات',
                    Icons.settings_input_component,
                    AppColors.opSales,
                    '/workspace/operations',
                    role),
                _buildWorkspaceTile(context, 'الحسابات', Icons.account_balance,
                    AppColors.opCustomers, '/workspace/accounting', role),
                _buildWorkspaceTile(context, 'المخزون', Icons.inventory_2,
                    AppColors.opInventory, '/workspace/inventory', role),
                _buildWorkspaceTile(context, 'الأطراف', Icons.people,
                    AppColors.opSuppliers, '/workspace/parties', role),
                _buildWorkspaceTile(context, 'التقارير', Icons.assessment,
                    AppColors.opReports, '/workspace/reports', role),
                _buildWorkspaceTile(
                    context,
                    'الإدارة',
                    Icons.admin_panel_settings,
                    AppColors.secondary,
                    '/workspace/admin',
                    role),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWorkspaceTile(BuildContext context, String title, IconData icon,
      Color color, String route, UserRole role) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppDimensions.sm),
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            Icon(Icons.chevron_left, color: color.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Center(
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          children: [
            _skeletonBox(height: 56),
            const SizedBox(height: AppDimensions.lg),
            _skeletonBox(height: 80),
            const SizedBox(height: AppDimensions.lg),
            _skeletonBox(height: 200),
            const SizedBox(height: AppDimensions.lg),
            _skeletonBox(height: 150),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, UserRole role) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) context.go('/');
        if (index == 1) context.push('/pos');
        if (index == 2) NewOperationSheet.show(context);
        if (index == 3) {
          final scaffold = Scaffold.of(context);
          if (scaffold.hasDrawer) scaffold.openDrawer();
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'POS'),
        BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline), label: 'جديد'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'القائمة'),
      ],
    );
  }
}
