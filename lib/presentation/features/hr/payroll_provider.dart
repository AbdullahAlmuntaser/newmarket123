import 'package:flutter/material.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class PayrollProvider with ChangeNotifier {
  final HRService _service;
  List<HRPayrollRun> _entries = [];
  bool _isLoading = false;

  PayrollProvider(this._service);

  List<HRPayrollRun> get entries => _entries;
  bool get isLoading => _isLoading;

  Future<void> loadPayrollEntries() async {
    _isLoading = true;
    notifyListeners();
    _entries = await _service.getAllPayrollEntries();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> generatePayroll(String period) async {
    _isLoading = true;
    notifyListeners();
    await _service.generatePayroll(period);
    await loadPayrollEntries();
    _isLoading = false;
    notifyListeners();
  }

  Future<List<HRPayrollDetail>> getPayrollLines(int runId) async {
    return await _service.getPayrollLines(runId);
  }
}
