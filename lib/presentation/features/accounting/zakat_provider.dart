import 'package:flutter/material.dart';
import 'package:supermarket/core/services/zakat_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ZakatProvider with ChangeNotifier {
  final ZakatService _service;

  List<ZakatCalculation> _calculations = [];
  ZakatSummary? _summary;
  bool _isLoading = false;

  ZakatProvider(this._service);

  List<ZakatCalculation> get calculations => _calculations;
  ZakatSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  Future<void> loadData({String? period, String? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _calculations = await _service.getZakatCalculations(
        period: period,
        status: status,
      );
      _summary = await _service.getZakatSummary();
    } catch (e) {
      debugPrint('ZakatProvider error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ZakatCalculation?> calculateZakat({
    required String period,
    String calculationType = 'ANNUAL',
  }) async {
    try {
      final calculation = await _service.calculateZakat(
        period: period,
        calculationType: calculationType,
      );
      await loadData();
      return calculation;
    } catch (e) {
      debugPrint('Zakat calculation error: $e');
      return null;
    }
  }

  Future<void> markAsFiled(String id, {String? notes}) async {
    await _service.markAsFiled(id, notes: notes);
    await loadData();
  }

  Future<void> markAsPaid(String id) async {
    await _service.markAsPaid(id);
    await loadData();
  }
}
