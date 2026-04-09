import 'package:flutter/material.dart';
import 'package:supermarket/core/services/shift_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ShiftProvider with ChangeNotifier {
  final ShiftService _shiftService;
  Shift? _activeShift;
  bool _isLoading = false;

  ShiftProvider(this._shiftService);

  Shift? get activeShift => _activeShift;
  bool get isLoading => _isLoading;
  bool get hasActiveShift => _activeShift != null;

  Future<void> checkActiveShift(String userId) async {
    _isLoading = true;
    notifyListeners();
    _activeShift = await _shiftService.getActiveShift(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> openShift(
    String userId,
    double openingCash, {
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();
    await _shiftService.openShift(userId, openingCash, note: note);
    await checkActiveShift(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> closeShift(double closingCash, {String? note}) async {
    if (_activeShift == null) return;
    _isLoading = true;
    notifyListeners();
    await _shiftService.closeShift(_activeShift!.id, closingCash, note: note);
    _activeShift = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<double> getExpectedCash() async {
    if (_activeShift == null) return 0.0;
    return await _shiftService.calculateExpectedCash(_activeShift!);
  }
}
