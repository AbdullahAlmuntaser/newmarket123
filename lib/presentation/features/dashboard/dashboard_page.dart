import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboard)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickActions,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  l10n.seedProducts,
                  Icons.dataset,
                  () => _seedData(db, context),
                ),
                _buildActionCard(
                  context,
                  l10n.viewSales,
                  Icons.history,
                  () => context.go('/sales'),
                ),
                _buildActionCard(
                  context,
                  l10n.pos,
                  Icons.point_of_sale,
                  () => context.go('/pos'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'نظرة عامة على المبيعات (آخر 7 أيام)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildSalesChart(db),
            const SizedBox(height: 32),
            Text(l10n.overview, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildStatsGrid(db, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(AppDatabase db) {
    return SizedBox(
      height: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<Sale>>(
            stream: db.select(db.sales).watch(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Logic to group sales by date and map to FlSpot
              final sales = snapshot.data!;
              final spots = <FlSpot>[];
              for (int i = 0; i < 7; i++) {
                final date = DateTime.now().subtract(Duration(days: 6 - i));
                final dailyTotal = sales
                    .where(
                      (s) =>
                          s.createdAt.day == date.day &&
                          s.createdAt.month == date.month,
                    )
                    .fold(0.0, (sum, s) => sum + s.total);
                spots.add(FlSpot(i.toDouble(), dailyTotal));
              }

              return LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  titlesData: const FlTitlesData(show: true),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  // ... بقية الميثودات (_buildActionCard, _buildStatsGrid, etc) تبقى كما هي

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 150,
      height: 120,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(AppDatabase db, AppLocalizations l10n) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          l10n.products,
          db.select(db.products).watch().map((l) => l.length.toString()),
        ),
        _buildStatCard(
          l10n.totalSales,
          db.select(db.sales).watch().map((l) => l.length.toString()),
        ),
        _buildStatCard(
          l10n.revenue,
          db
              .select(db.sales)
              .watch()
              .map(
                (l) =>
                    l.fold(0.0, (sum, s) => sum + s.total).toStringAsFixed(2),
              ),
        ),
        _buildStatCard(
          l10n.pendingSync,
          db.select(db.syncQueue).watch().map((l) => l.length.toString()),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, Stream<String> valueStream) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            StreamBuilder<String>(
              stream: valueStream,
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? '0',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedData(AppDatabase db, BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Coffee',
              sku: 'CONF001',
              sellPrice: const drift.Value(3.5),
              stock: const drift.Value(50.0),
            ),
          );
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Tea',
              sku: 'TEA001',
              sellPrice: const drift.Value(2.5),
              stock: const drift.Value(100.0),
            ),
          );
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Cake',
              sku: 'CAKE001',
              sellPrice: const drift.Value(5.0),
              stock: const drift.Value(20.0),
            ),
          );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.seedDataAdded)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
