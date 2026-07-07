import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/workspaces/workspace_base.dart';
import 'package:supermarket/presentation/widgets/navigation/breadcrumbs.dart';

class AccountingWorkspace extends StatelessWidget {
  const AccountingWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: 'مساحة عمل الحسابات',
      breadcrumbs: [
        BreadcrumbItem(title: 'الرئيسية', route: '/'),
        BreadcrumbItem(title: 'الحسابات', route: '/workspace/accounting'),
      ],
      children: [
        WorkspaceSection(
          title: 'ACCOUNTING CORE',
          children: [
            WorkspaceTile(
              title: 'شجرة الحسابات',
              icon: Icons.account_tree_rounded,
              color: Colors.purple,
              onTap: () => context.push('/accounting/coa'),
            ),
            WorkspaceTile(
              title: 'القيود اليومية',
              icon: Icons.article_rounded,
              onTap: () => context.push('/accounting/manual-journal'),
            ),
            WorkspaceTile(
              title: 'دفتر الأستاذ',
              icon: Icons.menu_book_rounded,
              onTap: () => context.push('/accounting/general-ledger'),
            ),
            WorkspaceTile(
              title: 'ميزان المراجعة',
              icon: Icons.scale_rounded,
              onTap: () => context.push('/accounting/trial-balance'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'FINANCIAL STATEMENTS',
          children: [
            WorkspaceTile(
              title: 'الميزانية العمومية',
              icon: Icons.account_balance_rounded,
              color: Colors.indigo,
              onTap: () => context.push('/accounting/balance-sheet'),
            ),
            WorkspaceTile(
              title: 'قائمة الدخل',
              icon: Icons.trending_up_rounded,
              onTap: () => context.push('/accounting/income-statement'),
            ),
            WorkspaceTile(
              title: 'التدفقات النقدية',
              icon: Icons.money_rounded,
              onTap: () => context.push('/accounting/cash-flow'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'CASH & BANK',
          children: [
            WorkspaceTile(
              title: 'سند قبض',
              icon: Icons.add_card_rounded,
              color: Colors.teal,
              onTap: () =>
                  context.push('/accounting/manual-voucher?receipt=true'),
            ),
            WorkspaceTile(
              title: 'سند صرف',
              icon: Icons.remove_circle_outline_rounded,
              onTap: () =>
                  context.push('/accounting/manual-voucher?receipt=false'),
            ),
            WorkspaceTile(
              title: 'التحويلات',
              icon: Icons.swap_horiz_rounded,
              onTap: () => context.push('/accounting/transfers'),
            ),
            WorkspaceTile(
              title: 'إدارة الشيكات',
              icon: Icons.fact_check_rounded,
              onTap: () => context.push('/accounting/checks'),
            ),
          ],
        ),
        WorkspaceSection(
          title: 'SETUP & PERIODS',
          children: [
            WorkspaceTile(
              title: 'الفترات المحاسبية',
              icon: Icons.date_range_rounded,
              onTap: () => context.push('/accounting/periods'),
            ),
            WorkspaceTile(
              title: 'مراكز التكلفة',
              icon: Icons.pie_chart_rounded,
              onTap: () => context.push('/accounting/cost-centers'),
            ),
            WorkspaceTile(
              title: 'إدارة الورديات',
              icon: Icons.loop_rounded,
              onTap: () => context.push('/accounting/shifts'),
            ),
          ],
        ),
      ],
    );
  }
}
