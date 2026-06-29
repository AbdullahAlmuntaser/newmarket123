import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/workspaces/workspace_base.dart';
import 'package:supermarket/presentation/widgets/navigation/breadcrumbs.dart';

class OperationsWorkspace extends StatelessWidget {
  const OperationsWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: 'مساحة عمل العمليات',
      breadcrumbs: [
        BreadcrumbItem(title: 'الرئيسية', route: '/'),
        BreadcrumbItem(title: 'العمليات', route: '/workspace/operations'),
      ],
      children: [
        WorkspaceSection(
          title: 'SALES SECTION',
          children: [
            WorkspaceTile(
              title: 'بيع جديد (POS)',
              icon: Icons.point_of_sale_rounded,
              color: Colors.green,
              onTap: () => context.push('/pos'),
            ),
            WorkspaceTile(
              title: 'فواتير البيع',
              icon: Icons.history_rounded,
              onTap: () => context.push('/sales'),
            ),
            WorkspaceTile(
              title: 'المرتجعات',
              icon: Icons.assignment_return_rounded,
              onTap: () => context.push('/sales/returns'),
            ),
            WorkspaceTile(
              title: 'عروض الأسعار',
              icon: Icons.description_outlined,
              onTap: () {}, // Not yet implemented in router but in spec
            ),
          ],
        ),
        WorkspaceSection(
          title: 'PURCHASES SECTION',
          children: [
            WorkspaceTile(
              title: 'فواتير الشراء',
              icon: Icons.shopping_bag_rounded,
              color: Colors.blue,
              onTap: () => context.push('/purchases'),
            ),
            WorkspaceTile(
              title: 'شراء جديد',
              icon: Icons.add_shopping_cart_rounded,
              onTap: () => context.push('/purchases/new'),
            ),
            WorkspaceTile(
              title: 'مرتجع شراء',
              icon: Icons.keyboard_return_rounded,
              onTap: () => context.push('/purchases/returns'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'PAYMENTS SECTION',
          children: [
            WorkspaceTile(
              title: 'التحصيلات',
              icon: Icons.payments_rounded,
              color: Colors.orange,
              onTap: () =>
                  context.push('/accounting/manual-voucher?receipt=true'),
            ),
            WorkspaceTile(
              title: 'المدفوعات',
              icon: Icons.payment_rounded,
              onTap: () =>
                  context.push('/accounting/manual-voucher?receipt=false'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'REPORTS SECTION',
          children: [
            WorkspaceTile(
              title: 'تقارير المبيعات',
              icon: Icons.bar_chart_rounded,
              onTap: () => context.push('/reports/sales'),
            ),
            WorkspaceTile(
              title: 'تقرير الضريبة',
              icon: Icons.summarize_rounded,
              onTap: () => context.push('/reports/vat'),
            ),
          ],
        ),
      ],
    );
  }
}
