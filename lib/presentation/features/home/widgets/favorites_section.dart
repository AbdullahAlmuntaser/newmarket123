import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';
import 'package:supermarket/core/services/fast_access_service.dart';

class FavoritesSection extends StatelessWidget {
  const FavoritesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandCenterProvider>();
    final fastAccess = context.watch<FastAccessService>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 'default';

    final favoriteItems = fastAccess.items
        .where((item) => provider.isFavorite(item.route))
        .toList();

    if (favoriteItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_border, size: 20, color: AppColors.warning),
              SizedBox(width: AppDimensions.sm),
              Text('المفضلة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.lg),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.star_outline, color: Colors.grey[400], size: 32),
                const SizedBox(height: AppDimensions.sm),
                Text('اضغط على ⭐ في أي شاشة لتثبيتها هنا',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, size: 20, color: AppColors.warning),
            const SizedBox(width: AppDimensions.sm),
            const Text('المفضلة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${favoriteItems.length} عناصر',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: favoriteItems.map((item) {
            return InkWell(
              onTap: () => context.push(item.route),
              onLongPress: () => provider.toggleFavorite(item.route, userId),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(item.title,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
