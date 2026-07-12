import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/workspaces/workspace_base.dart';
import 'package:supermarket/presentation/widgets/navigation/breadcrumbs.dart';

class AdminWorkspace extends StatelessWidget {
  const AdminWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: 'مساحة عمل الإدارة',
      breadcrumbs: [
        BreadcrumbItem(title: 'الرئيسية', route: '/'),
        BreadcrumbItem(title: 'الإدارة', route: '/workspace/admin'),
      ],
      children: [
        WorkspaceSection(
          title: 'SYSTEM SETTINGS',
          children: [
            WorkspaceTile(
              title: 'إعدادات النظام',
              icon: Icons.settings_suggest_rounded,
              color: Colors.blueGrey,
              onTap: () => context.push('/settings/system'),
            ),
            WorkspaceTile(
              title: 'أسعار صرف العملات',
              icon: Icons.monetization_on_rounded,
              color: Colors.green,
              onTap: () => context.push('/settings/currency-rates'),
            ),
            WorkspaceTile(
              title: 'الإعدادات المتقدمة',
              icon: Icons.settings_applications_rounded,
              onTap: () => context.push('/settings/advanced'),
            ),
            WorkspaceTile(
              title: 'الطابعة',
              icon: Icons.print_rounded,
              onTap: () => context.push('/settings/printer'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'SECURITY & ACCESS',
          children: [
            WorkspaceTile(
              title: 'الصلاحيات',
              icon: Icons.security_rounded,
              color: Colors.red,
              onTap: () => context.push('/settings/permissions'),
            ),
            WorkspaceTile(
              title: 'أدوار المستخدمين',
              icon: Icons.supervised_user_circle_rounded,
              onTap: () => context.push('/user-roles'),
            ),
            WorkspaceTile(
              title: 'سير الموافقات',
              icon: Icons.approval_rounded,
              onTap: () => context.push('/approvals'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'DATA & SYNC',
          children: [
            WorkspaceTile(
              title: 'النسخ الاحتياطي',
              icon: Icons.backup_rounded,
              color: Colors.blue,
              onTap: () => context.push('/settings/backup'),
            ),
            WorkspaceTile(
              title: 'المزامنة',
              icon: Icons.sync_rounded,
              onTap: () => context.push('/sync'),
            ),
          ],
        ),
      ],
    );
  }
}
