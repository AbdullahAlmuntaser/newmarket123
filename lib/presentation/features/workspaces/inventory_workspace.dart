import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/workspaces/workspace_base.dart';
import 'package:supermarket/presentation/widgets/navigation/breadcrumbs.dart';

class InventoryWorkspace extends StatelessWidget {
  const InventoryWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: 'مساحة عمل المخزون',
      breadcrumbs: [
        BreadcrumbItem(title: 'الرئيسية', route: '/'),
        BreadcrumbItem(title: 'المخزون', route: '/workspace/inventory'),
      ],
      children: [
        WorkspaceSection(
          title: 'PRODUCTS & MASTER DATA',
          children: [
            WorkspaceTile(
              title: 'المنتجات',
              icon: Icons.inventory_2_rounded,
              color: Colors.brown,
              onTap: () => context.push('/products'),
            ),
            WorkspaceTile(
              title: 'الفئات',
              icon: Icons.category_rounded,
              onTap: () => context.push('/categories'),
            ),
            WorkspaceTile(
              title: 'التصنيع (BOM)',
              icon: Icons.precision_manufacturing_rounded,
              onTap: () => context.push('/manufacturing/bom'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'WAREHOUSE OPERATIONS',
          children: [
            WorkspaceTile(
              title: 'المستودعات',
              icon: Icons.warehouse_rounded,
              color: Colors.blueGrey,
              onTap: () => context.push('/inventory/warehouses'),
            ),
            WorkspaceTile(
              title: 'جرد المخزون',
              icon: Icons.fact_check_rounded,
              onTap: () => context.push('/inventory/stock-take'),
            ),
            WorkspaceTile(
              title: 'التحويل المخزني',
              icon: Icons.swap_horizontal_circle_rounded,
              onTap: () => context.push('/inventory/transfer'),
            ),
            WorkspaceTile(
              title: 'حركات المخزن',
              icon: Icons.list_alt_rounded,
              onTap: () => context.push('/reports/inventory'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'ALERTS & MANAGEMENT',
          children: [
            WorkspaceTile(
              title: 'تنبيهات النقص',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              onTap: () => context.push('/inventory/low-stock-alert'),
            ),
            WorkspaceTile(
              title: 'مدير المستودع',
              icon: Icons.manage_accounts_rounded,
              onTap: () => context.push('/inventory/warehouse-manager'),
            ),
            WorkspaceTile(
              title: 'أوامر الإنتاج',
              icon: Icons.assignment_rounded,
              onTap: () => context.push('/manufacturing/production-orders'),
            ),
            WorkspaceTile(
              title: 'تقرير الورديات',
              icon: Icons.loop_rounded,
              onTap: () => context.push('/inventory/shifts'),
            ),
          ],
        ),
      ],
    );
  }
}
