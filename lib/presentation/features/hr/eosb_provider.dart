import 'package:flutter/material.dart';
import 'package:supermarket/core/services/eosb_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class EOSBProvider with ChangeNotifier {
  final EndOfServiceBenefitService _service;
  final AppDatabase _db;

  List<EndOfServiceBenefit> _eosbList = [];
  EOSBSummary? _summary;
  List<Employee> _employees = [];
  bool _isLoading = false;

  EOSBProvider(this._service, this._db);

  List<EndOfServiceBenefit> get eosbList => _eosbList;
  EOSBSummary? get summary => _summary;
  List<Employee> get employees => _employees;
  bool get isLoading => _isLoading;

  Future<void> loadData({String? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _eosbList = await _service.getAllEOSB(status: status);
      _summary = await _service.getEOSBSummary();
      _employees = await _db.select(_db.employees).get();
    } catch (e) {
      debugPrint('EOSBProvider error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<EndOfServiceBenefit?> calculateEOSB({
    required String employeeId,
    required DateTime endDate,
    String calculationMethod = 'STANDARD',
  }) async {
    try {
      final eosb = await _service.calculateEOSB(
        employeeId: employeeId,
        endDate: endDate,
        calculationMethod: calculationMethod,
      );
      await loadData();
      return eosb;
    } catch (e) {
      debugPrint('EOSB calculation error: $e');
      return null;
    }
  }

  Future<void> markAsPaid(String id) async {
    await _service.markAsPaid(id);
    await loadData();
  }
}
