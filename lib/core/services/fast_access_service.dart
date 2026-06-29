import 'package:flutter/material.dart';
import 'package:supermarket/core/auth/user_role.dart';
import 'package:supermarket/core/auth/access_guard.dart';

class FastAccessItem {
  final String title;
  final String route;
  final IconData icon;
  final String category;
  final List<String> keywords;

  FastAccessItem({
    required this.title,
    required this.route,
    required this.icon,
    required this.category,
    this.keywords = const [],
  });
}

class FastAccessService extends ChangeNotifier {
  final List<FastAccessItem> _items = [
    FastAccessItem(
        title: 'لوحة التحكم',
        route: '/',
        icon: Icons.grid_view,
        category: 'عام'),
    FastAccessItem(
        title: 'نقطة البيع (POS)',
        route: '/pos',
        icon: Icons.point_of_sale,
        category: 'المبيعات',
        keywords: ['كاشير', 'بيع']),
    FastAccessItem(
        title: 'فاتورة مبيعات جديدة',
        route: '/sales/invoice',
        icon: Icons.add_shopping_cart,
        category: 'المبيعات'),
    FastAccessItem(
        title: 'سجل المبيعات',
        route: '/sales',
        icon: Icons.history,
        category: 'المبيعات'),
    FastAccessItem(
        title: 'مرتجعات المبيعات',
        route: '/sales/returns',
        icon: Icons.assignment_return,
        category: 'المبيعات'),
    FastAccessItem(
        title: 'قائمة المنتجات',
        route: '/products',
        icon: Icons.inventory_2,
        category: 'المخزون',
        keywords: ['أصناف', 'مخزن']),
    FastAccessItem(
        title: 'الفئات',
        route: '/categories',
        icon: Icons.category,
        category: 'المخزون'),
    FastAccessItem(
        title: 'إضافة عملية شراء',
        route: '/purchases/new',
        icon: Icons.shopping_bag,
        category: 'المشتريات'),
    FastAccessItem(
        title: 'قائمة المشتريات',
        route: '/purchases',
        icon: Icons.receipt_long,
        category: 'المشتريات'),
    FastAccessItem(
        title: 'شجرة الحسابات',
        route: '/accounting/coa',
        icon: Icons.account_tree,
        category: 'المحاسبة'),
    FastAccessItem(
        title: 'دفتر الأستاذ',
        route: '/accounting/general-ledger',
        icon: Icons.menu_book,
        category: 'المحاسبة'),
    FastAccessItem(
        title: 'الميزانية العمومية',
        route: '/accounting/balance-sheet',
        icon: Icons.account_balance,
        category: 'المحاسبة'),
    FastAccessItem(
        title: 'قائمة الدخل',
        route: '/accounting/income-statement',
        icon: Icons.show_chart,
        category: 'المحاسبة'),
    FastAccessItem(
        title: 'كشف حساب عميل',
        route: '/accounting/customer-ledger',
        icon: Icons.person_search,
        category: 'المحاسبة'),
    FastAccessItem(
        title: 'كشف حساب مورد',
        route: '/accounting/supplier-ledger',
        icon: Icons.local_shipping,
        category: 'المحاسبة'),
    FastAccessItem(
        title: 'إدارة الموظفين',
        route: '/hr/employees',
        icon: Icons.badge,
        category: 'الموارد البشرية'),
    FastAccessItem(
        title: 'مسيرات الرواتب',
        route: '/hr/payroll',
        icon: Icons.payments,
        category: 'الموارد البشرية'),
    FastAccessItem(
        title: 'تقرير المبيعات',
        route: '/reports/sales',
        icon: Icons.bar_chart,
        category: 'التقارير'),
    FastAccessItem(
        title: 'تقرير المخزون',
        route: '/reports/inventory',
        icon: Icons.inventory,
        category: 'التقارير'),
    FastAccessItem(
        title: 'إعدادات النظام',
        route: '/settings/system',
        icon: Icons.settings,
        category: 'الإعدادات'),
  ];

  final List<String> _recentRoutes = [];
  final List<String> _favoriteRoutes = [];

  List<FastAccessItem> get items => _items;
  List<String> get recentRoutes => _recentRoutes;
  List<String> get favoriteRoutes => _favoriteRoutes;

  List<FastAccessItem> getSearchableItems(UserRole role) {
    return _items
        .where((item) => AccessGuard.canAccess(item.route, role))
        .toList();
  }

  void addToRecent(String route) {
    if (_recentRoutes.contains(route)) {
      _recentRoutes.remove(route);
    }
    _recentRoutes.insert(0, route);
    if (_recentRoutes.length > 5) {
      _recentRoutes.removeLast();
    }
    notifyListeners();
  }

  void toggleFavorite(String route) {
    if (_favoriteRoutes.contains(route)) {
      _favoriteRoutes.remove(route);
    } else {
      _favoriteRoutes.add(route);
    }
    notifyListeners();
  }

  List<FastAccessItem> search(String query, UserRole role) {
    final searchable = getSearchableItems(role);
    if (query.isEmpty) return searchable;

    final lowercaseQuery = query.toLowerCase();
    return searchable.where((item) {
      return item.title.toLowerCase().contains(lowercaseQuery) ||
          item.category.toLowerCase().contains(lowercaseQuery) ||
          item.keywords.any((kw) => kw.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }
}
