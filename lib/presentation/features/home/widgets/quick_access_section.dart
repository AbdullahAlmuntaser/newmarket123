import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';

class QuickAccessSection extends StatelessWidget {
  const QuickAccessSection({super.key});

  @override
  Widget build(BuildContext context) {
    final operations = context.watch<CommandCenterProvider>().recentOperations;

    if (operations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 20, color: AppColors.info),
            const SizedBox(width: AppDimensions.sm),
            const Text('الوصول السريع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text('مسح السجل', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: operations.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppDimensions.sm),
            itemBuilder: (context, index) {
              final op = operations[index];
              return _buildOperationChip(context, op);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOperationChip(BuildContext context, RecentOperation op) {
    return InkWell(
      onTap: () => context.push(op.route),
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: op.color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: op.color.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(op.icon, color: op.color, size: 22),
            const SizedBox(height: 4),
            Text(
              op.title,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: op.color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _timeAgo(op.timestamp),
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} ي';
  }
}
