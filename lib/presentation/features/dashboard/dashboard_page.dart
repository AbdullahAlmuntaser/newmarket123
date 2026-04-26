import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/reporting_service.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';
import 'dashboard_provider.dart';
import 'package:supermarket/injection_container.dart';

class DashboardPage extends StatelessWidget {
  final String currentUserId; // إضافة مستخدم حالي
  const DashboardPage({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم')),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          final data = provider.data;
          if (data == null) return const Center(child: Text('لا توجد بيانات'));

          return RefreshIndicator(
            onRefresh: provider.refreshData,
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              children: [
                _buildStatCard('مبيعات اليوم', data.totalSalesToday.toStringAsFixed(2), Icons.shopping_cart, Colors.green),
                
                // دمج التقارير المالية مع حماية الصلاحيات
                PermissionGuard(
                  permission: 'VIEW_FINANCIALS',
                  child: FutureBuilder<Map<String, double>>(
                    future: sl<ReportingService>().getProfitAndLoss(
                      DateTime.now().subtract(const Duration(days: 1)), DateTime.now()
                    ),
                    builder: (context, snapshot) {
                      final netProfit = snapshot.data?['netProfit'] ?? 0.0;
                      return _buildStatCard('صافي الربح الفعلي', netProfit.toStringAsFixed(2), Icons.attach_money, Colors.blue);
                    },
                  ),
                ),
                
                _buildStatCard('قيمة المخزون', data.inventoryValue.toStringAsFixed(2), Icons.inventory, Colors.orange),
                _buildStatCard('تنبيهات المخزون', '${data.lowStockCount}', Icons.warning, Colors.red),
                _buildStatCard('تجاوز ائتمان', '${data.creditLimitExceededCount}', Icons.account_balance_wallet, Colors.purple),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
