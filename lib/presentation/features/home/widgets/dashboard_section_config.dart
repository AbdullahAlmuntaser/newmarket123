import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';

class DashboardSectionConfig extends StatelessWidget {
  const DashboardSectionConfig({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXxl)),
      ),
      builder: (_) => const DashboardSectionConfig(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandCenterProvider>();
    final sections = provider.sections;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: AppDimensions.md),
          const Text('تخصيص الداشبورد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimensions.sm),
          Text('اسحب لإعادة الترتيب، واضغط على العين لإخفاء/إظهار القسم',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: AppDimensions.md),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            onReorder: (oldIndex, newIndex) =>
                provider.reorderSections(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final section = sections[index];
              return ListTile(
                key: ValueKey(section.id),
                leading: Icon(section.icon,
                    color: section.isVisible ? AppColors.primary : Colors.grey),
                title: Text(section.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: section.isVisible ? null : Colors.grey,
                    )),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        section.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color:
                            section.isVisible ? AppColors.primary : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          provider.toggleSectionVisibility(section.id),
                    ),
                    const Icon(Icons.drag_handle, color: Colors.grey),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppDimensions.md),
        ],
      ),
    );
  }
}
