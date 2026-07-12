import 'package:flutter/material.dart';
import 'package:supermarket/core/services/withholding_tax_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class WhtProvider with ChangeNotifier {
  final WithholdingTaxService _service;
  List<WithholdingTaxEntry> _entries = [];
  WhtSummary? _summary;
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _status;

  WhtProvider(this._service);

  List<WithholdingTaxEntry> get entries => _entries;
  WhtSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get status => _status;

  Future<void> loadEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    _isLoading = true;
    notifyListeners();

    _startDate = startDate;
    _endDate = endDate;
    _status = status;

    _entries = await _service.getWhtEntries(
      startDate: startDate,
      endDate: endDate,
      status: status,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSummary(DateTime startDate, DateTime endDate) async {
    _isLoading = true;
    notifyListeners();

    _summary = await _service.getWhtSummary(
      startDate: startDate,
      endDate: endDate,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsFiled(String entryId, String referenceNumber) async {
    await _service.markAsFiled(entryId, referenceNumber);
    await loadEntries(
      startDate: _startDate,
      endDate: _endDate,
      status: _status,
    );
  }

  Future<void> markAsPaid(String entryId) async {
    await _service.markAsPaid(entryId);
    await loadEntries(
      startDate: _startDate,
      endDate: _endDate,
      status: _status,
    );
  }
}
