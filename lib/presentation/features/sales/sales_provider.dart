import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/erp_data_service.dart';
import 'package:supermarket/injection_container.dart';

/// Alert types for sales
enum SalesAlertType {
  outOfStock,
  lowStock,
  priceBelowCost,
  overCreditLimit,
  approachingCreditLimit,
}

/// Alert item for sales
class SalesAlert {
  final SalesAlertType type;
  final String message;
  final bool isBlocking; // True if it should block the sale
  final String? productId;

  SalesAlert({
    required this.type,
    required this.message,
    required this.isBlocking,
    this.productId,
  });
}

/// Provider for smart sales features
class SalesProvider with ChangeNotifier {
  final AppDatabase db;
  final ErpDataService erpService = sl<ErpDataService>();

  SalesProvider(this.db);

  // Smart info caches
  CustomerSmartData? _customerData;
  final Map<String, ProductSmartData> _productDataCache = {};
  final List<SalesAlert> _alerts = [];

  // Getters
  CustomerSmartData? get customerData => _customerData;
  List<SalesAlert> get alerts => _alerts;
  ProductSmartData? getProductData(String productId) => _productDataCache[productId];

  // ==================== SMART CUSTOMER ====================

  /// Load customer info when customer is selected
  Future<void> loadCustomerData(String customerId, {String? productId}) async {
    _customerData = await erpService.getCustomerSmartData(customerId, productId: productId);
    notifyListeners();
  }

  /// Clear customer info
  void clearCustomer() {
    _customerData = null;
    notifyListeners();
  }

  // ==================== SMART PRODUCT INFO ====================

  /// Load product info when adding a product
  Future<void> loadProductData(String productId) async {
    final data = await erpService.getProductSmartData(productId);
    _productDataCache[productId] = data;
    notifyListeners();
  }

  // ==================== SALES ALERTS ====================

  /// Check for stock availability and price warnings
  void checkAlerts({double? newSaleTotal, bool isCredit = false}) {
    _alerts.clear();

    if (_customerData != null && isCredit) {
      final totalWithNewSale = _customerData!.currentBalance + (newSaleTotal ?? 0);
      if (totalWithNewSale > _customerData!.creditLimit && _customerData!.creditLimit > 0) {
        _alerts.add(SalesAlert(
          type: SalesAlertType.overCreditLimit,
          message: 'العميل تجاوز حد الائتمان!',
          isBlocking: true,
        ));
      }
    }

    notifyListeners();
  }

  /// Check a single product for warnings
  void checkProductAlert(String productId, double price, double quantity) {
    final productData = _productDataCache[productId];
    if (productData == null) return;

    if (productData.currentStock < quantity) {
      _alerts.add(SalesAlert(
        type: SalesAlertType.outOfStock,
        message: 'المخزون غير كافٍ',
        isBlocking: true,
        productId: productId,
      ));
    }

    if (price < productData.averageCost && productData.averageCost > 0) {
      _alerts.add(SalesAlert(
        type: SalesAlertType.priceBelowCost,
        message: 'السعر أقل من التكلفة',
        isBlocking: false,
        productId: productId,
      ));
    }

    notifyListeners();
  }
}
