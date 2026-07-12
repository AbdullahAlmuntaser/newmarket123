import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/core/services/sales_commission_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CommissionProvider with ChangeNotifier {
  final SalesCommissionService _service;
  final AppDatabase _db;

  List<SalesCommission> _commissions = [];
  SalesTarget? _currentTarget;
  CommissionSummary? _summary;
  List<User> _salespersons = [];
  bool _isLoading = false;

  CommissionProvider(this._service, this._db);

  List<SalesCommission> get commissions => _commissions;
  SalesTarget? get currentTarget => _currentTarget;
  CommissionSummary? get summary => _summary;
  List<User> get salespersons => _salespersons;
  bool get isLoading => _isLoading;

  Future<void> loadCommissions({
    String? salespersonId,
    String? period,
    String? status,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _commissions = await _service.getCommissions(
        salespersonId: salespersonId,
        period: period,
        status: status,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTarget(String salespersonId, String period) async {
    _currentTarget = await _service.getSalesTarget(
      salespersonId: salespersonId,
      period: period,
    );
    notifyListeners();
  }

  Future<void> loadSummary(String salespersonId, String period) async {
    _summary = await _service.getCommissionSummary(
      salespersonId: salespersonId,
      period: period,
    );
    notifyListeners();
  }

  Future<void> loadSalespersons() async {
    _salespersons = await (_db.select(_db.users)..limit(200)).get();
    notifyListeners();
  }

  Future<void> loadData({String? salespersonId, String? period}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadSalespersons();
      if (salespersonId != null && period != null) {
        await Future.wait([
          loadCommissions(salespersonId: salespersonId, period: period),
          loadTarget(salespersonId, period),
          loadSummary(salespersonId, period),
        ]);
      } else {
        await loadCommissions();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SalesTarget> createTarget({
    required String salespersonId,
    required String period,
    required Decimal targetAmount,
    required Decimal commissionRate,
  }) async {
    final target = await _service.createSalesTarget(
      salespersonId: salespersonId,
      period: period,
      targetAmount: targetAmount,
      commissionRate: commissionRate,
    );
    _currentTarget = target;
    notifyListeners();
    return target;
  }

  Future<void> markAsPaid(List<String> commissionIds) async {
    await _service.markAsPaid(commissionIds);

    for (final id in commissionIds) {
      final index = _commissions.indexWhere((c) => c.id == id);
      if (index != -1) {
        _commissions[index] = _commissions[index].copyWith(
          status: 'PAID',
          paidAt: Value(DateTime.now()),
        );
      }
    }
    notifyListeners();
  }
}
