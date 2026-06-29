import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';

class ActivityTimelineSection extends StatelessWidget {
  const ActivityTimelineSection({super.key});

  @override
  Widget build(BuildContext context) {
    final operations = context.watch<CommandCenterProvider>().recentOperations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timeline, size: 20, color: AppColors.secondary),
            SizedBox(width: AppDimensions.sm),
            Text('الجدول الزمني',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        if (operations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.lg),
            decoration: BoxDecoration(
              color: AppColors.sectionBg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Column(
              children: [
                Icon(Icons.timeline, color: Colors.grey[300], size: 32),
                const SizedBox(height: AppDimensions.sm),
                Text('لم تُ执行 أي عملية بعد',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          )
        else
          ...operations.take(8).map((op) => _buildTimelineItem(context, op)),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, RecentOperation op) {
    final time = op.timestamp;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => context.push(op.route),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.sm, horizontal: AppDimensions.sm),
        child: Row(
          children: [
            Column(
              children: [
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
                const SizedBox(height: 4),
                Container(
                    width: 2, height: 24, color: op.color.withOpacity(0.3)),
              ],
            ),
            const SizedBox(width: AppDimensions.md),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: op.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(op.icon, color: op.color, size: 16),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(op.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(op.subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: Colors.grey[300], size: 16),
          ],
        ),
      ),
    );
  }
}
