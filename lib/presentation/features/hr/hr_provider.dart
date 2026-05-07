import 'package:flutter/material.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class HRProvider with ChangeNotifier {
  final HRService _service;
  List<Employee> _employees = [];
  bool _isLoading = false;

  HRProvider(this._service);

  List<Employee> get employees => _employees;
  bool get isLoading => _isLoading;

  Future<void> loadEmployees() async {
    _isLoading = true;
    notifyListeners();
    _employees = await _service.getAllEmployees();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addEmployee(EmployeesCompanion employee) async {
    await _service.addEmployee(employee);
    await loadEmployees();
  }

  Future<void> updateEmployee(Employee employee) async {
    await _service.updateEmployee(employee);
    await loadEmployees();
  }

  Future<void> deleteEmployee(String id) async {
    await _service.deleteEmployee(id);
    await loadEmployees();
  }
}
