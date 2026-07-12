import 'package:flutter/material.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class HRProvider with ChangeNotifier {
  final HRService _service;
  List<HREmployee> _employees = [];
  bool _isLoading = false;
  String? _error;

  HRProvider(this._service);

  List<HREmployee> get employees => _employees;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEmployees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _employees = await _service.getAllEmployees();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addEmployee(HREmployeesCompanion employee) async {
    _error = null;
    try {
      await _service.addEmployee(employee);
      await loadEmployees();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> updateEmployee(HREmployeesCompanion employee) async {
    _error = null;
    try {
      await _service.updateEmployee(employee);
      await loadEmployees();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> deleteEmployee(String id) async {
    _error = null;
    try {
      await _service.deleteEmployee(id);
      await loadEmployees();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }
}
