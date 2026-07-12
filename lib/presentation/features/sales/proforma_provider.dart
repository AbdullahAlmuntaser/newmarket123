import 'package:flutter/material.dart';
import 'package:supermarket/core/services/proforma_service.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ProformaProvider with ChangeNotifier {
  final ProformaService _service;

  List<ProformaInvoice> _proformas = [];
  ProformaInvoice? _currentProforma;
  List<ProformaInvoiceItem> _currentItems = [];
  bool _isLoading = false;

  ProformaProvider(this._service);

  List<ProformaInvoice> get proformas => _proformas;
  ProformaInvoice? get currentProforma => _currentProforma;
  List<ProformaInvoiceItem> get currentItems => _currentItems;
  bool get isLoading => _isLoading;

  Future<void> loadData({String? customerId, DocumentStatus? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _proformas = await _service.getAllProformas(
        customerId: customerId,
        status: status,
      );
    } catch (e) {
      debugPrint('ProformaProvider error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProforma(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentProforma = await _service.getProforma(id);
      _currentItems = await _service.getProformaItems(id);
    } catch (e) {
      debugPrint('ProformaProvider loadProforma error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ProformaInvoice?> createProforma({
    String? customerId,
    required List<ProformaItemInput> items,
    double discount = 0,
    double taxRate = 15,
    String? notes,
    String? validUntil,
  }) async {
    try {
      final proforma = await _service.createProforma(
        customerId: customerId,
        items: items,
        discount: discount,
        taxRate: taxRate,
        notes: notes,
        validUntil: validUntil,
      );
      await loadData();
      return proforma;
    } catch (e) {
      debugPrint('ProformaProvider createProforma error: $e');
      return null;
    }
  }

  Future<void> cancelProforma(String id) async {
    await _service.cancelProforma(id);
    await loadData();
  }
}
