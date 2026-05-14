import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportsHubPage extends StatelessWidget {
  const ReportsHubPage({super.key});

  static const _reports = [
    _ReportLink('تقارير المبيعات', Icons.receipt_long, '/reports/sales'),
    _ReportLink('ربحية المنتجات', Icons.trending_up, '/reports/profitability'),
    _ReportLink('إجمالي الربح', Icons.analytics, '/reports/gross-profit'),
    _ReportLink('تقارير المخزون', Icons.inventory_2, '/reports/inventory'),
    _ReportLink('تدقيق المخزون', Icons.fact_check, '/reports/inventory-audit'),
    _ReportLink('حركة صنف', Icons.swap_horiz, '/reports/item-movement'),
    _ReportLink('المصروفات حسب المركز', Icons.account_tree, '/reports/expenses-by-center'),
    _ReportLink('ضريبة القيمة المضافة', Icons.percent, '/reports/vat'),
    _ReportLink('أعمار الديون', Icons.schedule, '/reports/aging'),
    _ReportLink('توقع التدفق النقدي', Icons.waterfall_chart, '/reports/cash-flow'),
    _ReportLink('سجل التدقيق', Icons.history, '/reports/audit'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مركز التقارير')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.35,
        ),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go(report.route),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(report.icon, size: 42, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      report.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportLink {
  const _ReportLink(this.title, this.icon, this.route);

  final String title;
  final IconData icon;
  final String route;
}
