import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/fast_access_service.dart';
import 'package:supermarket/core/auth/user_role.dart';

// ─── Data Models ───

class RecentOperation {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  final String route;

  const RecentOperation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
    required this.route,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'route': route,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RecentOperation.fromJson(Map<String, dynamic> json) =>
      RecentOperation(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        icon: Icons.receipt,
        color: Colors.blue,
        route: json['route'] ?? '/',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}

class AlertItem {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String route;
  final AlertSeverity severity;

  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.route,
    this.severity = AlertSeverity.info,
  });
}

enum AlertSeverity { info, warning, critical }

class TodayStats {
  final double sales;
  final double purchases;
  final double profit;
  final int invoiceCount;
  final int newCustomers;
  final int productsSold;
  final double cashBalance;
  final double bankBalance;
  final double yesterdaySales;
  final double yesterdayPurchases;
  final double weekSales;
  final double weekPurchases;

  const TodayStats({
    this.sales = 0,
    this.purchases = 0,
    this.profit = 0,
    this.invoiceCount = 0,
    this.newCustomers = 0,
    this.productsSold = 0,
    this.cashBalance = 0,
    this.bankBalance = 0,
    this.yesterdaySales = 0,
    this.yesterdayPurchases = 0,
    this.weekSales = 0,
    this.weekPurchases = 0,
  });

  double get salesTrend => yesterdaySales > 0
      ? ((sales - yesterdaySales) / yesterdaySales * 100)
      : 0;
  double get purchasesTrend => yesterdayPurchases > 0
      ? ((purchases - yesterdayPurchases) / yesterdayPurchases * 100)
      : 0;

  static const empty = TodayStats();
}

class DashboardSection {
  final String id;
  final String title;
  final IconData icon;
  final bool isVisible;
  final int order;

  const DashboardSection({
    required this.id,
    required this.title,
    required this.icon,
    this.isVisible = true,
    this.order = 0,
  });

  DashboardSection copyWith({bool? isVisible, int? order}) => DashboardSection(
        id: id,
        title: title,
        icon: icon,
        isVisible: isVisible ?? this.isVisible,
        order: order ?? this.order,
      );
}

// ─── Provider ───

class CommandCenterProvider extends ChangeNotifier {
  final AppDatabase _db;
  final FastAccessService _fastAccessService;

  CommandCenterProvider(this._db, this._fastAccessService);

  // State
  bool _isLoading = true;
  TodayStats _todayStats = TodayStats.empty;
  List<RecentOperation> _recentOperations = [];
  List<AlertItem> _alerts = [];
  List<DashboardSection> _sections = [];
  String _searchQuery = '';
  List<FastAccessItem> _searchResults = [];

  // Getters
  bool get isLoading => _isLoading;
  TodayStats get todayStats => _todayStats;
  List<RecentOperation> get recentOperations => _recentOperations;
  List<AlertItem> get alerts => _alerts;
  List<DashboardSection> get sections => _sections;
  String get searchQuery => _searchQuery;
  List<FastAccessItem> get searchResults => _searchResults;
  int get unreadAlertsCount =>
      _alerts.where((a) => a.severity != AlertSeverity.info).length;

  // ─── Load All Dashboard Data ───

  Future<void> loadDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadTodayStats(),
        _loadRecentOperations(),
        _loadAlerts(),
        _loadSectionConfig(),
      ]);
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTodayStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

    final todaySalesList = await (_db.select(_db.sales)
          ..where((t) => t.createdAt.isBiggerOrEqual(Variable(todayStart))))
        .get();
    final yesterdaySalesList = await (_db.select(_db.sales)
          ..where((t) =>
              t.createdAt.isBiggerOrEqual(Variable(yesterdayStart)) &
              t.createdAt.isSmallerThan(Variable(todayStart))))
        .get();
    final weekSalesList = await (_db.select(_db.sales)
          ..where((t) => t.createdAt.isBiggerOrEqual(Variable(weekStart))))
        .get();

    final todayPurchasesList = await (_db.select(_db.purchases)
          ..where((t) => t.createdAt.isBiggerOrEqual(Variable(todayStart))))
        .get();
    final yesterdayPurchasesList = await (_db.select(_db.purchases)
          ..where((t) =>
              t.createdAt.isBiggerOrEqual(Variable(yesterdayStart)) &
              t.createdAt.isSmallerThan(Variable(todayStart))))
        .get();
    final weekPurchasesList = await (_db.select(_db.purchases)
          ..where((t) => t.createdAt.isBiggerOrEqual(Variable(weekStart))))
        .get();

    final customersToday = await (_db.select(_db.customers)
          ..where((t) => t.createdAt.isBiggerOrEqual(Variable(todayStart))))
        .get();

    final saleItemsToday = await (_db.select(_db.saleItems)
          ..where(
              (t) => t.saleId.isIn(todaySalesList.map((s) => s.id).toList())))
        .get();

    _todayStats = TodayStats(
      sales: todaySalesList.fold(0.0, (num sum, s) => sum + s.total.toDouble()),
      purchases: todayPurchasesList.fold(
          0.0, (num sum, p) => sum + p.total.toDouble()),
      profit:
          todaySalesList.fold(0.0, (num sum, s) => sum + s.total.toDouble()) -
              todayPurchasesList.fold(
                  0.0, (num sum, p) => sum + p.total.toDouble()),
      invoiceCount: todaySalesList.length,
      newCustomers: customersToday.length,
      productsSold: saleItemsToday.length,
      cashBalance: 0,
      bankBalance: 0,
      yesterdaySales: yesterdaySalesList.fold(
          0.0, (num sum, s) => sum + s.total.toDouble()),
      yesterdayPurchases: yesterdayPurchasesList.fold(
          0.0, (num sum, p) => sum + p.total.toDouble()),
      weekSales:
          weekSalesList.fold(0.0, (num sum, s) => sum + s.total.toDouble()),
      weekPurchases:
          weekPurchasesList.fold(0.0, (num sum, p) => sum + p.total.toDouble()),
    );
  }

  Future<void> _loadRecentOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('cc_recent_ops') ?? [];
    _recentOperations = raw
        .map((r) {
          try {
            return RecentOperation.fromJson(jsonDecode(r));
          } catch (_) {
            return null;
          }
        })
        .whereType<RecentOperation>()
        .take(10)
        .toList();
  }

  Future<void> _loadAlerts() async {
    _alerts = [];

    final allProducts = await (_db.select(_db.products)).get();
    final lowStock = allProducts.where((p) {
      final stockVal = p.stock.toDouble();
      final alertVal = p.alertLimit.toDouble();
      return stockVal <= alertVal && alertVal > 0;
    }).toList();

    for (final p in lowStock.take(5)) {
      _alerts.add(AlertItem(
        id: 'low_stock_${p.id}',
        title: 'مخزون منخفض',
        message: '${p.name} - المخزون الحالي: ${p.stock}',
        icon: Icons.inventory_2_outlined,
        color: Colors.orange,
        route: '/low-stock',
        severity: AlertSeverity.warning,
      ));
    }

    final allCustomers = await (_db.select(_db.customers)).get();
    final overdueCustomers =
        allCustomers.where((c) => c.balance.toDouble() > 0).toList();
    for (final c in overdueCustomers.take(3)) {
      _alerts.add(AlertItem(
        id: 'overdue_${c.id}',
        title: 'عميل متأخر',
        message: '${c.name} - رصيد: ${c.balance}',
        icon: Icons.person_off_outlined,
        color: Colors.red,
        route: '/accounting/customer-ledger',
        severity: AlertSeverity.critical,
      ));
    }
  }

  // ─── Search ───

  void search(String query, {String role = 'admin'}) {
    _searchQuery = query;
    if (query.isEmpty) {
      _searchResults = [];
    } else {
      _searchResults = _fastAccessService.search(query, _parseRole(role));
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  UserRole _parseRole(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      default:
        return UserRole.cashier;
    }
  }

  // ─── Recent Operations ───

  Future<void> addRecentOperation(RecentOperation op) async {
    _recentOperations.removeWhere((r) => r.route == op.route);
    _recentOperations.insert(0, op);
    if (_recentOperations.length > 10) _recentOperations.removeLast();
    await _saveRecentOperations();
    notifyListeners();
  }

  Future<void> _saveRecentOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _recentOperations.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('cc_recent_ops', raw);
  }

  // ─── Section Config ───

  Future<void> _loadSectionConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('cc_sections');

    final defaults = [
      const DashboardSection(
          id: 'today', title: 'أعمال اليوم', icon: Icons.today, order: 0),
      const DashboardSection(
          id: 'attention',
          title: 'مركز الانتباه',
          icon: Icons.notifications_active,
          order: 1),
      const DashboardSection(
          id: 'operations',
          title: 'عمليات سريعة',
          icon: Icons.flash_on,
          order: 2),
      const DashboardSection(
          id: 'favorites', title: 'المفضلة', icon: Icons.star, order: 3),
      const DashboardSection(
          id: 'quick_access',
          title: 'الوصول السريع',
          icon: Icons.history,
          order: 4),
      const DashboardSection(
          id: 'timeline',
          title: 'الجدول الزمني',
          icon: Icons.timeline,
          order: 5),
    ];

    if (raw != null && raw.isNotEmpty) {
      try {
        _sections = raw.map((r) {
          final map = jsonDecode(r);
          return DashboardSection(
            id: map['id'],
            title: map['title'],
            icon: Icons.circle,
            isVisible: map['visible'] ?? true,
            order: map['order'] ?? 0,
          );
        }).toList();
      } catch (_) {
        _sections = defaults;
      }
    } else {
      _sections = defaults;
    }
    _sections.sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> toggleSectionVisibility(String sectionId) async {
    _sections = _sections.map((s) {
      if (s.id == sectionId) return s.copyWith(isVisible: !s.isVisible);
      return s;
    }).toList();
    await _saveSectionConfig();
    notifyListeners();
  }

  Future<void> reorderSections(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    final item = _sections.removeAt(oldIndex);
    _sections.insert(newIndex, item);
    for (int i = 0; i < _sections.length; i++) {
      _sections[i] = _sections[i].copyWith(order: i);
    }
    await _saveSectionConfig();
    notifyListeners();
  }

  Future<void> _saveSectionConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _sections
        .map((s) => jsonEncode({
              'id': s.id,
              'title': s.title,
              'visible': s.isVisible,
              'order': s.order,
            }))
        .toList();
    await prefs.setStringList('cc_sections', raw);
  }

  // ─── Favorites (persisted per user) ───

  List<String> _favoriteRoutes = [];

  List<String> get favoriteRoutes => _favoriteRoutes;

  Future<void> loadFavorites(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteRoutes = prefs.getStringList('cc_fav_$userId') ?? [];
    notifyListeners();
  }

  Future<void> toggleFavorite(String route, String userId) async {
    if (_favoriteRoutes.contains(route)) {
      _favoriteRoutes.remove(route);
    } else {
      _favoriteRoutes.add(route);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cc_fav_$userId', _favoriteRoutes);
    notifyListeners();
  }

  bool isFavorite(String route) => _favoriteRoutes.contains(route);
}
