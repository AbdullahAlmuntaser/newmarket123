import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';

class FloatingQuickActions extends StatefulWidget {
  const FloatingQuickActions({super.key});

  @override
  State<FloatingQuickActions> createState() => _FloatingQuickActionsState();
}

class _FloatingQuickActionsState extends State<FloatingQuickActions>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: AppDimensions.animNormal);
    _scaleAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _rotateAnim = Tween(begin: 0.0, end: 0.75)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ..._buildMiniActions(context),
        const SizedBox(height: AppDimensions.md),
        ScaleTransition(
          scale: _scaleAnim,
          child: RotationTransition(
            turns: _rotateAnim,
            child: FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMiniActions(BuildContext context) {
    final actions = [
      const _MiniAction(
          label: 'بيع',
          icon: Icons.point_of_sale,
          color: AppColors.opSales,
          route: '/pos'),
      const _MiniAction(
          label: 'شراء',
          icon: Icons.shopping_bag,
          color: AppColors.opPurchases,
          route: '/purchases/new'),
      const _MiniAction(
          label: 'عميل',
          icon: Icons.person_add,
          color: AppColors.opCustomers,
          route: '/customers'),
      const _MiniAction(
          label: 'مورد',
          icon: Icons.local_shipping,
          color: AppColors.opSuppliers,
          route: '/suppliers'),
      const _MiniAction(
          label: 'منتج',
          icon: Icons.add_box,
          color: AppColors.opInventory,
          route: '/products'),
      const _MiniAction(
          label: 'تقرير',
          icon: Icons.assessment,
          color: AppColors.opReports,
          route: '/reports/sales'),
    ];

    return actions.asMap().entries.map((entry) {
      final i = entry.key;
      final action = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 100 + i * 50),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: FloatingActionButton.small(
            heroTag: 'mini_${action.label}',
            onPressed: () {
              _toggle();
              context.push(action.route);
            },
            backgroundColor: action.color,
            child: Icon(action.icon, color: Colors.white, size: 18),
          ),
        ),
      );
    }).toList();
  }
}

class _MiniAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _MiniAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.route});
}
