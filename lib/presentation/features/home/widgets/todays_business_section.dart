import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';

class TodaysBusinessSection extends StatelessWidget {
  const TodaysBusinessSection({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<CommandCenterProvider>().todayStats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'أعمال اليوم', Icons.today),
        const SizedBox(height: AppDimensions.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                    ? 3
                    : 2;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppDimensions.sm,
              crossAxisSpacing: AppDimensions.sm,
              childAspectRatio: 2.2,
              children: [
                _buildKPICard(
                  title: 'مبيعات اليوم',
                  value: stats.sales.toStringAsFixed(0),
                  trend: stats.salesTrend,
                  icon: Icons.trending_up,
                  gradient: AppColors.primaryGradient,
                  lightColor: AppColors.cardSales,
                ),
                _buildKPICard(
                  title: 'مشتريات اليوم',
                  value: stats.purchases.toStringAsFixed(0),
                  trend: stats.purchasesTrend,
                  icon: Icons.shopping_bag,
                  gradient: AppColors.successGradient,
                  lightColor: AppColors.cardPurchases,
                ),
                _buildKPICard(
                  title: 'عدد الفواتير',
                  value: stats.invoiceCount.toString(),
                  trend: 0,
                  icon: Icons.receipt_long,
                  gradient: AppColors.warningGradient,
                  lightColor: AppColors.cardInventory,
                ),
                _buildKPICard(
                  title: 'العملاء الجدد',
                  value: '${stats.newCustomers}',
                  trend: 0,
                  icon: Icons.person_add,
                  gradient: const LinearGradient(
                      colors: [Color(0xFF5E35B1), Color(0xFF9575CD)]),
                  lightColor: AppColors.cardCustomers,
                ),
                _buildKPICard(
                  title: 'الأرباح',
                  value: stats.profit.toStringAsFixed(0),
                  trend: 0,
                  icon: Icons.show_chart,
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF4DB6AC)]),
                  lightColor: AppColors.cardCash,
                ),
                _buildKPICard(
                  title: 'المنتجات المباعة',
                  value: '${stats.productsSold}',
                  trend: 0,
                  icon: Icons.inventory_2,
                  gradient: AppColors.errorGradient,
                  lightColor: AppColors.cardAlert,
                ),
                _buildKPICard(
                  title: 'مبيعات هذا الأسبوع',
                  value: stats.weekSales.toStringAsFixed(0),
                  trend: 0,
                  icon: Icons.date_range,
                  gradient: const LinearGradient(
                      colors: [Color(0xFF546E7A), Color(0xFF90A4AE)]),
                  lightColor: AppColors.sectionBg,
                ),
                _buildKPICard(
                  title: 'مشتريات هذا الأسبوع',
                  value: stats.weekPurchases.toStringAsFixed(0),
                  trend: 0,
                  icon: Icons.calendar_today,
                  gradient: const LinearGradient(
                      colors: [Color(0xFFD84315), Color(0xFFFF8A65)]),
                  lightColor: AppColors.cardSuppliers,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppDimensions.sm),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required double trend,
    required IconData icon,
    required Gradient gradient,
    required Color lightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Icon(icon, color: Colors.white54, size: 18),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              if (trend != 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend > 0
                        ? Colors.greenAccent.withOpacity(0.3)
                        : Colors.redAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: trend > 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
