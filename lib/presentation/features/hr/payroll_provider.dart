import 'package:flutter/material.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/core/services/payroll_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class PayrollProvider with ChangeNotifier {
  final HRService _hrService;
  final PayrollService _payrollService;
  List<HRPayrollRun> _entries = [];
  bool _isLoading = false;
  
  PayrollProvider(this._hrService, this._payrollService);
  
  List<HRPayrollRun> get entries => _entries;
  bool get isLoading => _isLoading;
  
  Future<void> loadPayrollEntries() async {
    _isLoading = true;
    notifyListeners();
    _entries = await _hrService.getAllPayrollEntries();
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> generatePayroll(String period) async {
    _isLoading = true;
    notifyListeners();
    await _hrService.generatePayroll(period);
    await loadPayrollEntries();
    _isLoading = false;
    notifyListeners();
  }
  
  Future<List<HRPayrollDetail>> getPayrollLines(int runId) async {
    return await _hrService.getPayrollLines(runId);
  }
  
  /// ترحيل قيد الرواتب للحسابات
  Future<void> postPayrollJournalEntry(int payrollRunId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _payrollService.postPayrollJournalEntry(payrollRunId);
      await loadPayrollEntries();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// سداد الرواتب
  Future<void> paySalaries(int payrollRunId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _payrollService.paySalaries(payrollRunId);
      await loadPayrollEntries();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
