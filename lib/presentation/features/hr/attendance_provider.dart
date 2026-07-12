import 'package:flutter/material.dart';
import 'package:supermarket/core/services/attendance_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AttendanceProvider with ChangeNotifier {
  final AttendanceService _service;
  List<AttendanceRecord> _records = [];
  AttendanceSummary? _summary;
  bool _isLoading = false;

  AttendanceProvider(this._service);

  List<AttendanceRecord> get records => _records;
  AttendanceSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  Future<void> clockIn(String employeeId, {String? notes}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.clockIn(employeeId: employeeId, notes: notes);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clockOut(String employeeId, {String? notes}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.clockOut(employeeId: employeeId, notes: notes);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAttendance(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    notifyListeners();
    _records = await _service.getEmployeeAttendance(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
    );
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSummary(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _isLoading = true;
    notifyListeners();
    _summary = await _service.getAttendanceSummary(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
    );
    _isLoading = false;
    notifyListeners();
  }
}
