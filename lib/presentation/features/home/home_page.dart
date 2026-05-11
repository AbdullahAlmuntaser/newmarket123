import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/widgets/notification_tray.dart';
import 'package:supermarket/presentation/features/dashboard/widgets/dynamic_dashboard.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.home),
        actions: [
          Builder(
            builder: (scaffoldContext) => IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Scaffold.of(scaffoldContext).openEndDrawer(),
            ),
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
        ElevatedButton.icon(
          onPressed: () => context.push('/pos'),
          icon: const Icon(Icons.point_of_sale),
          label: Text(l10n.newSale),
          style: ElevatedButton.styleFrom(minimumSize: const Size(150, 50)),
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/purchases/new'),
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(l10n.newPurchaseInvoice),
          style: ElevatedButton.styleFrom(minimumSize: const Size(150, 50)),
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/sales/returns'),
          icon: const Icon(Icons.assignment_return),
          label: Text(l10n.salesReturns),
          style: ElevatedButton.styleFrom(minimumSize: const Size(150, 50)),
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/purchases/returns'),
          icon: const Icon(Icons.assignment_return_outlined),
          label: Text(l10n.purchaseReturns),
          style: ElevatedButton.styleFrom(minimumSize: const Size(150, 50)),
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/products'),
          icon: const Icon(Icons.inventory_2),
          label: Text(l10n.products),
          style: ElevatedButton.styleFrom(minimumSize: const Size(150, 50)),
        ),
      ],
    );
  }
}
