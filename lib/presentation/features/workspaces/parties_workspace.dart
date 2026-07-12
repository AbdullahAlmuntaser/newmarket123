import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/workspaces/workspace_base.dart';
import 'package:supermarket/presentation/widgets/navigation/breadcrumbs.dart';

class PartiesWorkspace extends StatelessWidget {
  const PartiesWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: 'مساحة عمل الأطراف',
      breadcrumbs: [
        BreadcrumbItem(title: 'الرئيسية', route: '/'),
        BreadcrumbItem(title: 'الأطراف', route: '/workspace/parties'),
      ],
      children: [
        WorkspaceSection(
          title: 'CUSTOMERS',
          children: [
            WorkspaceTile(
              title: 'العملاء',
              icon: Icons.people_rounded,
              color: Colors.blue,
              onTap: () => context.push('/customers'),
            ),
            WorkspaceTile(
              title: 'نقاط الولاء',
              icon: Icons.loyalty_rounded,
              onTap: () => context.push('/loyalty'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'SUPPLIERS',
          children: [
            WorkspaceTile(
              title: 'الموردين',
              icon: Icons.local_shipping_rounded,
              color: Colors.orange,
              onTap: () => context.push('/suppliers'),
            ),
            WorkspaceTile(
              title: 'دفعات الموردين',
              icon: Icons.payments_rounded,
              onTap: () => context.push('/suppliers/payments'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'HUMAN RESOURCES',
          children: [
            WorkspaceTile(
              title: 'الموظفين',
              icon: Icons.badge_rounded,
              color: Colors.teal,
              onTap: () => context.push('/hr/employees'),
            ),
            WorkspaceTile(
              title: 'مسيرات الرواتب',
              icon: Icons.monetization_on_rounded,
              onTap: () => context.push('/hr/payroll'),
            ),
            WorkspaceTile(
              title: 'إدارة المستخدمين',
              icon: Icons.admin_panel_settings_rounded,
              onTap: () => context.push('/users'),
            ),
          ],
        ),
      ],
    );
  }
}
