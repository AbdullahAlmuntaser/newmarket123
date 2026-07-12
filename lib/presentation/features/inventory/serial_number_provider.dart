import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:supermarket/core/services/serial_number_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class SerialNumberProvider with ChangeNotifier {
  final SerialNumberService _service;
  final AppDatabase _db;

  List<SerialNumber> _serialNumbers = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  bool _isLoading = false;
  String? _error;

  String? _filterProductId;
  String? _filterWarehouseId;
  String? _filterStatus;

  List<SerialNumber> get serialNumbers => _serialNumbers;
  List<Product> get products => _products;
  List<Warehouse> get warehouses => _warehouses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get filterProductId => _filterProductId;
  String? get filterWarehouseId => _filterWarehouseId;
  String? get filterStatus => _filterStatus;

  SerialNumberProvider(this._service, this._db);

  Future<void> loadSerialNumbers({
    String? productId,
    String? warehouseId,
    String? status,
  }) async {
    _isLoading = true;
    _error = null;
    _filterProductId = productId;
    _filterWarehouseId = warehouseId;
    _filterStatus = status;
    notifyListeners();

    try {
      if (productId != null) {
        _serialNumbers = await _service.getSerialNumbersForProduct(
          productId: productId,
          warehouseId: warehouseId,
          status: status,
        );
      } else if (status != null || warehouseId != null) {
        final query = _db.select(_db.serialNumbers);
        if (warehouseId != null) {
          query.where((sn) => sn.warehouseId.equals(warehouseId));
        }
        if (status != null) {
          query.where((sn) => sn.status.equals(status));
        }
        query.orderBy([(sn) => OrderingTerm.asc(sn.serialNumber)]);
        _serialNumbers = await query.get();
      } else {
        final query = _db.select(_db.serialNumbers)
          ..orderBy([(sn) => OrderingTerm.asc(sn.serialNumber)]);
        _serialNumbers = await query.get();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _serialNumbers = await _service.getSerialNumberHistory(
        productId: productId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<SerialNumber>> loadAvailable(
    String productId,
    String warehouseId,
  ) async {
    try {
      return await _service.getAvailableSerialNumbers(
        productId: productId,
        warehouseId: warehouseId,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<void> loadDropdownData() async {
    try {
      _products = await (_db.select(_db.products)
            ..where((p) => p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();
      _warehouses = await (_db.select(_db.warehouses)
            ..orderBy([(w) => OrderingTerm.asc(w.name)]))
          .get();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<SerialNumber?> registerSerialNumber({
    required String productId,
    required String serialNumber,
    required String warehouseId,
    String? batchId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.registerSerialNumber(
        productId: productId,
        serialNumber: serialNumber,
        warehouseId: warehouseId,
        batchId: batchId,
      );
      await loadSerialNumbers(
        productId: _filterProductId,
        warehouseId: _filterWarehouseId,
        status: _filterStatus,
      );
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<int> bulkRegister({
    required String productId,
    required String warehouseId,
    required List<String> serialNumbers,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final count = await _service.bulkRegister(
        productId: productId,
        warehouseId: warehouseId,
        serialNumbers: serialNumbers,
      );
      await loadSerialNumbers(
        productId: _filterProductId,
        warehouseId: _filterWarehouseId,
        status: _filterStatus,
      );
      return count;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  Future<void> markAsSold({
    required String serialNumberId,
    required String saleId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.markAsSold(
        serialNumberId: serialNumberId,
        saleId: saleId,
      );
      await loadSerialNumbers(
        productId: _filterProductId,
        warehouseId: _filterWarehouseId,
        status: _filterStatus,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAsReturned({
    required String serialNumberId,
    String? warehouseId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.markAsReturned(
        serialNumberId: serialNumberId,
        warehouseId: warehouseId,
      );
      await loadSerialNumbers(
        productId: _filterProductId,
        warehouseId: _filterWarehouseId,
        status: _filterStatus,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> reserve({
    required String serialNumberId,
    required String salesOrderId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.reserve(
        serialNumberId: serialNumberId,
        salesOrderId: salesOrderId,
      );
      await loadSerialNumbers(
        productId: _filterProductId,
        warehouseId: _filterWarehouseId,
        status: _filterStatus,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearFilters() {
    _filterProductId = null;
    _filterWarehouseId = null;
    _filterStatus = null;
    notifyListeners();
  }
}
