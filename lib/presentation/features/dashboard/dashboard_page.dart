import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      drawer: const MainDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(l10n.overview, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildStatsGrid(db, l10n),
          const SizedBox(height: 24),
          Text('المبيعات (آخر 7 أيام)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSalesChart(db),
          const SizedBox(height: 24),
          Text(l10n.quickActions, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildQuickActionList(context, db, l10n),
        ],
      ),
    );
  }

  Widget _buildQuickActionList(BuildContext context, AppDatabase db, AppLocalizations l10n) {
    return Column(
      children: [
        _buildActionTile(context, l10n.seedProducts, Icons.dataset_rounded, () => _seedData(db, context)),
        _buildActionTile(context, l10n.viewSales, Icons.history_rounded, () => context.go('/sales')),
        _buildActionTile(context, l10n.pos, Icons.point_of_sale_rounded, () => context.go('/pos')),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
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
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final sales = snapshot.data!;
              final spots = <FlSpot>[];
              for (int i = 0; i < 7; i++) {
                final date = DateTime.now().subtract(Duration(days: 6 - i));
                final dailyTotal = sales.where((s) => s.createdAt.day == date.day && s.createdAt.month == date.month).fold(0.0, (sum, s) => sum + s.total);
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

  Widget _buildStatsGrid(AppDatabase db, AppLocalizations l10n) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(l10n.products, db.select(db.products).watch().map((l) => l.length.toString())),
        _buildStatCard(l10n.totalSales, db.select(db.sales).watch().map((l) => l.length.toString())),
        _buildStatCard(l10n.revenue, db.select(db.sales).watch().map((l) => l.fold(0.0, (sum, s) => sum + s.total).toStringAsFixed(2))),
        _buildStatCard(l10n.pendingSync, db.select(db.syncQueue).watch().map((l) => l.length.toString())),
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
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            StreamBuilder<String>(
              stream: valueStream,
              builder: (context, snapshot) {
                return Text(snapshot.data ?? '0', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
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
      await db.into(db.products).insert(ProductsCompanion.insert(name: 'Coffee', sku: 'CONF001', sellPrice: const drift.Value(3.5), stock: const drift.Value(50.0)));
      await db.into(db.products).insert(ProductsCompanion.insert(name: 'Tea', sku: 'TEA001', sellPrice: const drift.Value(2.5), stock: const drift.Value(100.0)));
      await db.into(db.products).insert(ProductsCompanion.insert(name: 'Cake', sku: 'CAKE001', sellPrice: const drift.Value(5.0), stock: const drift.Value(20.0)));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.seedDataAdded)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
