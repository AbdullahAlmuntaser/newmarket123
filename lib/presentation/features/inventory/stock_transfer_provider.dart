import 'package:flutter/material.dart';
import 'package:supermarket/core/services/stock_transfer_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class StockTransferProvider with ChangeNotifier {
  final StockTransferService _service;

  List<Warehouse> _warehouses = [];
  List<ProductBatch> _availableBatches = [];
  String? _selectedFromWarehouseId;
  String? _selectedToWarehouseId;
  List<TransferItemData> _transferItems = [];
  bool _isLoading = false;

  StockTransferProvider(this._service);

  List<Warehouse> get warehouses => _warehouses;
  List<ProductBatch> get availableBatches => _availableBatches;
  String? get selectedFromWarehouseId => _selectedFromWarehouseId;
  String? get selectedToWarehouseId => _selectedToWarehouseId;
  List<TransferItemData> get transferItems => _transferItems;
  bool get isLoading => _isLoading;

  Future<void> loadWarehouses() async {
    _isLoading = true;
    notifyListeners();
    _warehouses = await _service.getAllWarehouses();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setFromWarehouse(String? warehouseId) async {
    _selectedFromWarehouseId = warehouseId;
    _transferItems = [];
    if (warehouseId != null) {
      _availableBatches = await _service.getBatchesForWarehouse(warehouseId);
    } else {
      _availableBatches = [];
    }
    notifyListeners();
  }

  void setToWarehouse(String? warehouseId) {
    _selectedToWarehouseId = warehouseId;
    notifyListeners();
  }

  void addTransferItem(ProductBatch batch, double quantity) {
    final existingIndex = _transferItems.indexWhere(
      (item) => item.batchId == batch.id,
    );
    if (existingIndex >= 0) {
      _transferItems[existingIndex] = TransferItemData(
        productId: batch.productId,
        batchId: batch.id,
        quantity: _transferItems[existingIndex].quantity + quantity,
      );
    } else {
      _transferItems.add(
        TransferItemData(
          productId: batch.productId,
          batchId: batch.id,
          quantity: quantity,
        ),
      );
    }
    notifyListeners();
  }

  void removeTransferItem(String batchId) {
    _transferItems.removeWhere((item) => item.batchId == batchId);
    notifyListeners();
  }

  Future<void> submitTransfer(String? note) async {
    if (_selectedFromWarehouseId == null ||
        _selectedToWarehouseId == null ||
        _transferItems.isEmpty) {
      throw Exception('Please fill all required fields and add items.');
    }

    _isLoading = true;
    notifyListeners();
    try {
      await _service.processTransfer(
        fromWarehouseId: _selectedFromWarehouseId!,
        toWarehouseId: _selectedToWarehouseId!,
        items: _transferItems,
        note: note,
      );
      _transferItems = [];
      // Refresh batches
      _availableBatches = await _service.getBatchesForWarehouse(
        _selectedFromWarehouseId!,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
