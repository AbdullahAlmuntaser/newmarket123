import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:flutter/material.dart';
import 'package:supermarket/core/services/hr_service.dart';

class PayrollProvider with ChangeNotifier {
  final HRService _service;
  List<PayrollEntry> _entries = [];
  bool _isLoading = false;

  PayrollProvider(this._service);

  List<PayrollEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  Future<void> loadPayrollEntries() async {
    _isLoading = true;
    notifyListeners();
    _entries = await _service.getAllPayrollEntries();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> generatePayroll(int month, int year, {String? note}) async {
    _isLoading = true;
    notifyListeners();
    await _service.generatePayroll(month, year, note: note);
    await loadPayrollEntries();
    _isLoading = false;
    notifyListeners();
  }

  Future<List<PayrollLine>> getPayrollLines(String entryId) async {
    return await _service.getPayrollLines(entryId);
  }
}
