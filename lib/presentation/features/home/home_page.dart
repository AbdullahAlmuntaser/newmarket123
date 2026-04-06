import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/features/home/widgets/home_card.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.home),
        actions: [
          StreamBuilder<int>(
            stream: db.productsDao.watchLowStockCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => context.push('/low-stock'),
                    tooltip: l10n.lowStockItems,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const MainDrawer(),
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
            _buildOverviewGrid(context, db, l10n),
            const SizedBox(height: 24),
            Text(
              l10n.quickActions,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildQuickActions(context, db, l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewGrid(
    BuildContext context,
    AppDatabase db,
    AppLocalizations l10n,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StreamBuilder<double>(
          stream: db.salesDao.watchTotalRevenueToday(),
          builder: (context, snapshot) => HomeCard(
            icon: Icons.trending_up,
            title: l10n.todaySales,
            value: '${(snapshot.data ?? 0).toStringAsFixed(2)} SAR',
            color: Colors.green,
          ),
        ),
        StreamBuilder<double>(
          stream: db.salesDao.watchTotalProfitToday(),
          builder: (context, snapshot) => HomeCard(
            icon: Icons.account_balance_wallet,
            title: 'أرباح اليوم',
            value: '${(snapshot.data ?? 0).toStringAsFixed(2)} SAR',
            color: Colors.teal,
          ),
        ),
        StreamBuilder<int>(
          stream: db.productsDao.watchLowStockCount(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return HomeCard(
              icon: Icons.warning_amber_rounded,
              title: l10n.lowStockItems,
              value: '$count ${l10n.items}',
              color: count > 0 ? Colors.orange : Colors.blueGrey,
              onTap: () => context.push('/low-stock'),
            );
          },
        ),
        StreamBuilder<int>(
          stream: db.customersDao.watchTotalCustomers(),
          builder: (context, snapshot) => HomeCard(
            icon: Icons.people,
            title: l10n.totalCustomers,
            value: '${snapshot.data ?? 0}',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    AppDatabase db,
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
        if (true)
          ElevatedButton.icon(
            onPressed: () async {
              await db.seedData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seeded Data Successfully!')),
                );
              }
            },
            icon: const Icon(Icons.data_usage),
            label: const Text('Seed Data'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
      ],
    );
  }
}
