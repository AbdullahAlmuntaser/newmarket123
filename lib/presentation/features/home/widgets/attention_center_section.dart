import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';

class AttentionCenterSection extends StatelessWidget {
  const AttentionCenterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<CommandCenterProvider>().alerts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active,
                size: 20, color: AppColors.error),
            const SizedBox(width: AppDimensions.sm),
            const Text('مركز الانتباه',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (alerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text('${alerts.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        if (alerts.isEmpty)
          _buildEmptyState(context)
        else
          ...alerts.map((alert) => _buildAlertCard(context, alert)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          SizedBox(width: AppDimensions.sm),
          Text('لا توجد تنبيهات حالياً',
              style: TextStyle(
                  color: AppColors.success, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, AlertItem alert) {
    final bgColor = alert.severity == AlertSeverity.critical
        ? AppColors.errorLight
        : alert.severity == AlertSeverity.warning
            ? AppColors.warningLight
            : AppColors.infoLight;

    final borderColor = alert.severity == AlertSeverity.critical
        ? AppColors.error.withOpacity(0.3)
        : alert.severity == AlertSeverity.warning
            ? AppColors.warning.withOpacity(0.3)
            : AppColors.info.withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: InkWell(
        onTap: () => context.push(alert.route),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alert.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(alert.icon, color: alert.color, size: 20),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(alert.message,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
