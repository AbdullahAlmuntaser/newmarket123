import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Breadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Row(
            children: [
              InkWell(
                onTap: isLast ? null : () => context.go(item.route),
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: isLast ? Colors.grey[800] : Colors.blue,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!isLast)
                Icon(Icons.chevron_left, size: 16, color: Colors.grey[400]),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class BreadcrumbItem {
  final String title;
  final String route;

  BreadcrumbItem({required this.title, required this.route});
}
