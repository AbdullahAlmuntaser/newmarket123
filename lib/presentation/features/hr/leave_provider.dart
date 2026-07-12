import 'package:flutter/material.dart';
import 'package:supermarket/core/services/leave_management_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class LeaveProvider with ChangeNotifier {
  final LeaveManagementService _service;
  List<LeaveType> _leaveTypes = [];
  List<LeaveRequest> _leaveRequests = [];
  List<LeaveBalance> _employeeBalances = [];
  bool _isLoading = false;

  LeaveProvider(this._service);

  List<LeaveType> get leaveTypes => _leaveTypes;
  List<LeaveRequest> get leaveRequests => _leaveRequests;
  List<LeaveBalance> get employeeBalances => _employeeBalances;
  bool get isLoading => _isLoading;

  Future<void> loadLeaveTypes() async {
    _isLoading = true;
    notifyListeners();
    _leaveTypes = await _service.getAllLeaveTypes();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLeaveRequests({
    String? employeeId,
    String? status,
  }) async {
    _isLoading = true;
    notifyListeners();
    _leaveRequests = await _service.getLeaveRequests(
      employeeId: employeeId,
      status: status,
    );
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadEmployeeBalances(String employeeId) async {
    _isLoading = true;
    notifyListeners();
    _employeeBalances = await _service.getEmployeeBalances(employeeId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createLeaveType({
    required String name,
    required String code,
    required int defaultDays,
    bool isPaid = true,
  }) async {
    _isLoading = true;
    notifyListeners();
    await _service.createLeaveType(
      name: name,
      code: code,
      defaultDays: defaultDays,
      isPaid: isPaid,
    );
    await loadLeaveTypes();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createLeaveRequest({
    required String employeeId,
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    required int totalDays,
    String? reason,
  }) async {
    _isLoading = true;
    notifyListeners();
    await _service.createLeaveRequest(
      employeeId: employeeId,
      leaveTypeId: leaveTypeId,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      reason: reason,
    );
    await loadLeaveRequests();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> approveLeaveRequest({
    required String requestId,
    required String approvedBy,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();
    await _service.approveLeaveRequest(
      requestId: requestId,
      approvedBy: approvedBy,
      note: note,
    );
    await loadLeaveRequests();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> rejectLeaveRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  }) async {
    _isLoading = true;
    notifyListeners();
    await _service.rejectLeaveRequest(
      requestId: requestId,
      rejectedBy: rejectedBy,
      reason: reason,
    );
    await loadLeaveRequests();
    _isLoading = false;
    notifyListeners();
  }
}
