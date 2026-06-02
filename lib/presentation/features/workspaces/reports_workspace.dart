import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/workspaces/workspace_base.dart';
import 'package:supermarket/presentation/widgets/navigation/breadcrumbs.dart';

class ReportsWorkspace extends StatelessWidget {
  const ReportsWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: 'مساحة عمل التقارير',
      breadcrumbs: [
        BreadcrumbItem(title: 'الرئيسية', route: '/'),
        BreadcrumbItem(title: 'التقارير', route: '/workspace/reports'),
      ],
      children: [
        WorkspaceSection(
          title: 'SALES & PROFITS',
          children: [
            WorkspaceTile(
              title: 'تقارير المبيعات',
              icon: Icons.bar_chart_rounded,
              color: Colors.green,
              onTap: () => context.push('/reports/sales'),
            ),
            WorkspaceTile(
              title: 'الأرباح',
              icon: Icons.account_balance_wallet_rounded,
              onTap: () => context.push('/reports/gross-profit'),
            ),
            WorkspaceTile(
              title: 'ربحية المنتجات',
              icon: Icons.show_chart_rounded,
              onTap: () => context.push('/reports/profitability'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'INVENTORY & ASSETS',
          children: [
            WorkspaceTile(
              title: 'تقارير المخزون',
              icon: Icons.inventory_rounded,
              color: Colors.brown,
              onTap: () => context.push('/reports/inventory'),
            ),
            WorkspaceTile(
              title: 'جرد المستودعات',
              icon: Icons.fact_check_rounded,
              onTap: () => context.push('/reports/inventory-audit'),
            ),
            WorkspaceTile(
              title: 'حركة صنف',
              icon: Icons.compare_arrows_rounded,
              onTap: () => context.push('/reports/item-movement'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'FINANCIAL & AUDIT',
          children: [
            WorkspaceTile(
              title: 'الضرائب',
              icon: Icons.summarize_rounded,
              color: Colors.purple,
              onTap: () => context.push('/reports/vat'),
            ),
            WorkspaceTile(
              title: 'أعمار الديون',
              icon: Icons.timer_rounded,
              onTap: () => context.push('/reports/aging'),
            ),
            WorkspaceTile(
              title: 'سجل التدقيق',
              icon: Icons.history_edu_rounded,
              onTap: () => context.push('/reports/audit'),
            ),
          ],
        ),
      ],
    );
  }
}
