import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/dashboard_service.dart';

class DynamicDashboard extends StatelessWidget {
  const DynamicDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardService = Provider.of<DashboardService>(context);

    return FutureBuilder<DashboardStats>(
      future: dashboardService.getStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final stats = snapshot.data!;

        return Column(
          children: [
            _buildStatRow([
              _StatItem(title: 'مبيعات اليوم', value: stats.todaySales, icon: Icons.trending_up, color: Colors.green),
              _StatItem(title: 'مشتريات اليوم', value: stats.todayPurchases, icon: Icons.shopping_cart, color: Colors.blue),
            ]),
            const SizedBox(height: 16),
            _buildStatRow([
              _StatItem(title: 'رصيد الصندوق', value: stats.currentCash, icon: Icons.account_balance_wallet, color: Colors.teal),
              _StatItem(title: 'نواقص المخزون', value: stats.lowStockCount.toDouble(), icon: Icons.warning, color: Colors.orange, isCount: true),
            ]),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(List<_StatItem> items) {
    return Row(
      children: items.map((item) => Expanded(
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Icon(item.icon, color: item.color, size: 30),
                const SizedBox(height: 8),
                Text(item.title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  item.isCount ? item.value.toInt().toString() : item.value.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}

class _StatItem {
  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final bool isCount;

  _StatItem({required this.title, required this.value, required this.icon, required this.color, this.isCount = false});
}
