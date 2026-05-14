import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String category;
  final String? sourceKey;
  final String severity;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.category = 'general',
    this.sourceKey,
    this.severity = 'info',
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? category,
    String? sourceKey,
    String? severity,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      category: category ?? this.category,
      sourceKey: sourceKey ?? this.sourceKey,
      severity: severity ?? this.severity,
    );
  }
}

class NotificationService extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  final StreamController<List<AppNotification>> _controller =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get notificationsStream async* {
    yield List.unmodifiable(_notifications);
    yield* _controller.stream;
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  void notify({
    required String title,
    required String message,
    String category = 'general',
    String? sourceKey,
    String severity = 'info',
  }) {
    if (sourceKey != null) {
      _notifications.removeWhere(
        (n) => n.category == category && n.sourceKey == sourceKey,
      );
    }

    final n = AppNotification(
      id: const Uuid().v4(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      category: category,
      sourceKey: sourceKey,
      severity: severity,
    );
    _notifications.insert(0, n);
    _emit();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _emit();
    }
  }

  void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _emit();
  }

  void clearRead() {
    _notifications.removeWhere((n) => n.isRead);
    _emit();
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> showNotification(int id, String title, String body) async {
    notify(
      title: title,
      message: body,
      category: 'system',
      sourceKey: 'system:$id',
      severity: 'warning',
    );
  }

  Future<void> refreshOperationalAlerts(
    AppDatabase db, {
    DateTime? now,
    int expiringWithinDays = 30,
  }) async {
    final referenceDate = now ?? DateTime.now();
    await _refreshLowStockAlerts(db);
    await _refreshCreditLimitAlerts(db);
    await _refreshExpiringBatchAlerts(
      db,
      referenceDate,
      expiringWithinDays,
    );
    _emit();
  }

  Future<void> _refreshLowStockAlerts(AppDatabase db) async {
    _notifications.removeWhere((n) => n.category == 'inventory');
    final products = await (db.select(db.products)
          ..where(
            (p) =>
                p.isActive.equals(true) &
                p.stock.isSmallerOrEqual(p.alertLimit),
          ))
        .get();

    for (final product in products) {
      notify(
        title: 'تنبيه انخفاض المخزون',
        message:
            '${product.name}: الرصيد ${product.stock.toStringAsFixed(2)} أقل من أو يساوي حد التنبيه ${product.alertLimit.toStringAsFixed(2)}.',
        category: 'inventory',
        sourceKey: 'low_stock:${product.id}',
        severity: 'warning',
      );
    }
  }

  Future<void> _refreshCreditLimitAlerts(AppDatabase db) async {
    _notifications.removeWhere((n) => n.category == 'credit');
    final customers = await (db.select(db.customers)
          ..where(
            (c) =>
                c.creditLimit.isBiggerThan(const Variable(0)) &
                c.balance.isBiggerThan(c.creditLimit),
          ))
        .get();

    for (final customer in customers) {
      notify(
        title: 'تنبيه تجاوز الحد الائتماني',
        message:
            '${customer.name}: الرصيد ${customer.balance.toStringAsFixed(2)} تجاوز الحد ${customer.creditLimit.toStringAsFixed(2)}.',
        category: 'credit',
        sourceKey: 'credit_limit:${customer.id}',
        severity: 'critical',
      );
    }
  }

  Future<void> _refreshExpiringBatchAlerts(
    AppDatabase db,
    DateTime referenceDate,
    int expiringWithinDays,
  ) async {
    _notifications.removeWhere((n) => n.category == 'expiry');
    final thresholdDate = referenceDate.add(Duration(days: expiringWithinDays));
    final batches = await (db.select(db.productBatches)
          ..where(
            (b) => b.quantity.isBiggerThan(const Variable(0)) &
                b.expiryDate.isSmallerOrEqual(Variable(thresholdDate)),
          ))
        .get();

    for (final batch in batches) {
      notify(
        title: 'تنبيه قرب انتهاء دفعة',
        message:
            'الدفعة ${batch.batchNumber} ستنتهي قبل ${thresholdDate.toIso8601String().split('T').first}. الكمية ${batch.quantity.toStringAsFixed(2)}.',
        category: 'expiry',
        sourceKey: 'expiring_batch:${batch.id}',
        severity: 'warning',
      );
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_notifications));
    }
    notifyListeners();
  }
}
