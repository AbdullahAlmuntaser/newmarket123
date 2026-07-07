import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/auth/user_role.dart';
import 'package:supermarket/core/auth/access_guard.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';

class OperationCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<OperationAction> actions;

  const OperationCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.actions,
  });
}

class OperationAction {
  final String title;
  final String route;
  final IconData icon;

  const OperationAction(
      {required this.title, required this.route, required this.icon});
}

class NewOperationSheet extends StatelessWidget {
  const NewOperationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXxl)),
      ),
      builder: (_) => const NewOperationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final role = UserRole.fromString(auth.currentUser?.role ?? 'cashier');
    final provider = context.read<CommandCenterProvider>();

    final categories = _buildCategories(role);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusXxl)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline,
                        color: AppColors.primary),
                    const SizedBox(width: AppDimensions.sm),
                    const Text('إنشاء عملية جديدة',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _buildCategorySection(context, cat, provider);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySection(BuildContext context, OperationCategory cat,
      CommandCenterProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(cat.icon, size: 18, color: cat.color),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(cat.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cat.color)),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: cat.actions.map((action) {
              return ActionChip(
                avatar: Icon(action.icon, size: 16, color: cat.color),
                label: Text(action.title, style: const TextStyle(fontSize: 12)),
                backgroundColor: cat.color.withOpacity(0.05),
                side: BorderSide(color: cat.color.withOpacity(0.2)),
                onPressed: () {
                  Navigator.pop(context);
                  provider.addRecentOperation(RecentOperation(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: action.title,
                    subtitle: cat.title,
                    icon: action.icon,
                    color: cat.color,
                    timestamp: DateTime.now(),
                    route: action.route,
                  ));
                  context.push(action.route);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<OperationCategory> _buildCategories(UserRole role) {
    final cats = <OperationCategory>[];

    if (AccessGuard.canAccess('/pos', role)) {
      cats.add(const OperationCategory(
        title: 'المبيعات',
        icon: Icons.point_of_sale,
        color: AppColors.opSales,
        actions: [
          OperationAction(
              title: 'فاتورة بيع',
              route: '/pos',
              icon: Icons.add_shopping_cart),
          OperationAction(
              title: 'مرتجع بيع',
              route: '/sales/returns',
              icon: Icons.assignment_return),
          OperationAction(
              title: 'عرض سعر',
              route: '/sales/invoice',
              icon: Icons.request_quote),
          OperationAction(
              title: 'طلبية عميل',
              route: '/sales/orders',
              icon: Icons.shopping_cart_checkout),
        ],
      ));
    }

    if (AccessGuard.canAccess('/purchases/new', role)) {
      cats.add(const OperationCategory(
        title: 'المشتريات',
        icon: Icons.shopping_bag,
        color: AppColors.opPurchases,
        actions: [
          OperationAction(
              title: 'فاتورة شراء',
              route: '/purchases/new',
              icon: Icons.shopping_bag),
          OperationAction(
              title: 'مرتجع شراء',
              route: '/purchases/returns',
              icon: Icons.assignment_return),
          OperationAction(
              title: 'طلب شراء',
              route: '/purchases/orders',
              icon: Icons.receipt),
        ],
      ));
    }

    if (AccessGuard.canAccess('/customers', role)) {
      cats.add(const OperationCategory(
        title: 'العملاء',
        icon: Icons.people,
        color: AppColors.opCustomers,
        actions: [
          OperationAction(
              title: 'إضافة عميل', route: '/customers', icon: Icons.person_add),
          OperationAction(
              title: 'كشف حساب',
              route: '/accounting/customer-ledger',
              icon: Icons.person_search),
          OperationAction(
              title: 'سند قبض',
              route: '/accounting/manual-voucher?receipt=true',
              icon: Icons.receipt),
        ],
      ));
    }

    if (AccessGuard.canAccess('/suppliers', role)) {
      cats.add(const OperationCategory(
        title: 'الموردون',
        icon: Icons.local_shipping,
        color: AppColors.opSuppliers,
        actions: [
          OperationAction(
              title: 'إضافة مورد',
              route: '/suppliers',
              icon: Icons.add_business),
          OperationAction(
              title: 'كشف حساب',
              route: '/accounting/supplier-ledger',
              icon: Icons.receipt_long),
          OperationAction(
              title: 'سند صرف',
              route: '/accounting/manual-voucher?receipt=false',
              icon: Icons.payment),
        ],
      ));
    }

    if (AccessGuard.canAccess('/products', role)) {
      cats.add(const OperationCategory(
        title: 'المخزون',
        icon: Icons.inventory_2,
        color: AppColors.opInventory,
        actions: [
          OperationAction(
              title: 'إضافة منتج', route: '/products', icon: Icons.add_box),
          OperationAction(
              title: 'جرد مخزون',
              route: '/inventory/stock-take',
              icon: Icons.fact_check),
          OperationAction(
              title: 'تحويل مخزني',
              route: '/inventory/transfer',
              icon: Icons.swap_horiz),
          OperationAction(
              title: 'طباعة باركود',
              route: '/barcode-printing',
              icon: Icons.qr_code),
        ],
      ));
    }

    if (AccessGuard.canAccess('/accounting/cashbox', role)) {
      cats.add(const OperationCategory(
        title: 'الصناديق',
        icon: Icons.account_balance_wallet,
        color: AppColors.opCashbox,
        actions: [
          OperationAction(
              title: 'إيداع',
              route: '/accounting/cashbox',
              icon: Icons.savings),
          OperationAction(
              title: 'سحب',
              route: '/accounting/cashbox',
              icon: Icons.money_off),
          OperationAction(
              title: 'تحويل',
              route: '/accounting/transfers',
              icon: Icons.swap_horiz),
        ],
      ));
    }

    if (AccessGuard.canAccess('/reports/sales', role)) {
      cats.add(const OperationCategory(
        title: 'التقارير',
        icon: Icons.assessment,
        color: AppColors.opReports,
        actions: [
          OperationAction(
              title: 'تقرير المبيعات',
              route: '/reports/sales',
              icon: Icons.bar_chart),
          OperationAction(
              title: 'تقرير المشتريات',
              route: '/reports/purchases',
              icon: Icons.pie_chart),
          OperationAction(
              title: 'تقرير الأرباح',
              route: '/reports/profitability',
              icon: Icons.show_chart),
          OperationAction(
              title: 'تقرير المخزون',
              route: '/reports/inventory',
              icon: Icons.inventory),
        ],
      ));
    }

    return cats;
  }
}
