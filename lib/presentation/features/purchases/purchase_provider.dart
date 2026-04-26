import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Data class for supplier smart info
class SupplierSmartInfo {
  final double balance;
  final int totalInvoices;
  final double totalAmount;
  final DateTime? lastPurchaseDate;
  final double lastPurchaseAmount;

  SupplierSmartInfo({
    required this.balance,
    required this.totalInvoices,
    required this.totalAmount,
    this.lastPurchaseDate,
    required this.lastPurchaseAmount,
  });
}

/// Data class for product smart info during purchase entry
class ProductSmartInfo {
  final double currentStock;
  final double averageCost;
  final double lastPurchasePrice;
  final DateTime? lastPurchaseDate;
  final List<ProductPriceHistory> priceHistory;

  ProductSmartInfo({
    required this.currentStock,
    required this.averageCost,
    required this.lastPurchasePrice,
    this.lastPurchaseDate,
    required this.priceHistory,
  });
}

/// Price history item
class ProductPriceHistory {
  final double price;
  final DateTime date;
  final String supplierName;

  ProductPriceHistory({
    required this.price,
    required this.date,
    required this.supplierName,
  });
}

/// Alert types for purchases
enum PurchaseAlertType {
  highPrice,
  lowPrice,
  largeQuantity,
  lowStock,
  highStock,
}

/// Alert item for purchase
class PurchaseAlert {
  final PurchaseAlertType type;
  final String message;
  final bool isWarning;
  final String? productId;

  PurchaseAlert({
    required this.type,
    required this.message,
    required this.isWarning,
    this.productId,
  });
}

class PurchaseItemData {
  final Product product;
  double quantity;
  double unitPrice;
  double discountAmount;
  double taxPercent;
  DateTime? expiryDate;
  String? batchNumber;
  UnitConversion? selectedUnit;

  PurchaseItemData({
    required this.product,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountAmount = 0,
    this.taxPercent = 0,
    this.expiryDate,
    this.batchNumber,
    this.selectedUnit,
  });

  double get subtotal => quantity * unitPrice;
  double get total =>
      subtotal -
      discountAmount +
      (subtotal - discountAmount) * (taxPercent / 100);
}

class PurchaseProvider with ChangeNotifier {
  final AppDatabase db;
  final PurchaseService purchaseService;

  PurchaseProvider(this.db, this.purchaseService);

  // Smart info caches
  SupplierSmartInfo? _supplierInfo;
  final Map<String, ProductSmartInfo> _productInfoCache = {};
  final List<PurchaseAlert> _alerts = [];

  // Getters for smart info
  SupplierSmartInfo? get supplierInfo => _supplierInfo;
  List<PurchaseAlert> get alerts => _alerts;

  /// Get product smart info for a specific product
  ProductSmartInfo? getProductInfo(String productId) =>
      _productInfoCache[productId];

  Supplier? selectedSupplier;
  Warehouse? selectedWarehouse;
  DateTime selectedDate = DateTime.now();
  DateTime? dueDate;
  String paymentType = 'cash'; // cash / credit
  String? invoiceNumber;
  double headerDiscount = 0;
  double shippingCost = 0;
  double otherExpenses = 0;
  double landedCosts = 0;
  String notes = '';

  final List<PurchaseItemData> items = [];

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get totalDiscount =>
      items.fold(0.0, (sum, item) => sum + item.discountAmount) +
      headerDiscount;
  double get totalTax => items.fold(
    0.0,
    (sum, item) =>
        sum + (item.subtotal - item.discountAmount) * (item.taxPercent / 100),
  );
  double get grandTotal =>
      subtotal -
      totalDiscount +
      totalTax +
      shippingCost +
      otherExpenses +
      landedCosts;

  void addItem(Product product) {
    items.add(
      PurchaseItemData(
        product: product,
        unitPrice: product.buyPrice,
        taxPercent: product.taxRate,
      ),
    );
    notifyListeners();
  }

  void removeItem(int index) {
    items.removeAt(index);
    notifyListeners();
  }

  void updateItem(
    int index, {
    double? quantity,
    double? unitPrice,
    double? discount,
    DateTime? expiry,
    String? batch,
    UnitConversion? unit,
  }) {
    if (quantity != null) items[index].quantity = quantity;
    if (unitPrice != null) items[index].unitPrice = unitPrice;
    if (discount != null) items[index].discountAmount = discount;
    if (expiry != null) items[index].expiryDate = expiry;
    if (batch != null) items[index].batchNumber = batch;
    if (unit != null) items[index].selectedUnit = unit;
    notifyListeners();
  }

  Future<void> savePurchase({bool post = false, String? userId}) async {
    if (items.isEmpty) throw Exception('يجب إضافة أصناف أولاً');
    if (selectedSupplier == null && paymentType == 'credit') {
      throw Exception('يجب اختيار مورد للبيع الآجل');
    }

    final purchaseId = const Uuid().v4();

    final itemCompanions = items
        .map(
          (item) => PurchaseItemsCompanion.insert(
            purchaseId: purchaseId,
            productId: item.product.id,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            price: item.total,
            discount: Value(item.discountAmount),
            tax: Value(
              (item.subtotal - item.discountAmount) * (item.taxPercent / 100),
            ),
            unitId: Value(item.selectedUnit?.unitName),
            unitFactor: Value(item.selectedUnit?.factor ?? 1.0),
            batchNumber: Value(item.batchNumber),
            expiryDate: Value(item.expiryDate),
          ),
        )
        .toList();

    await purchaseService.createPurchase(
      supplierId: selectedSupplier!.id,
      items: itemCompanions,
      total: grandTotal,
    );

    if (post) {
      await purchaseService.postPurchase(purchaseId);
    }
  }

  void reset() {
    items.clear();
    selectedSupplier = null;
    selectedWarehouse = null;
    selectedDate = DateTime.now();
    dueDate = null;
    paymentType = 'cash';
    invoiceNumber = null;
    headerDiscount = 0;
    shippingCost = 0;
    otherExpenses = 0;
    landedCosts = 0;
    notes = '';
    _supplierInfo = null;
    _productInfoCache.clear();
    _alerts.clear();
    notifyListeners();
  }

  // ==================== SMART SUPPLIER SELECTION ====================

  /// Load supplier info when supplier is selected
  Future<void> loadSupplierInfo(Supplier supplier) async {
    // Get supplier balance from database
    _supplierInfo = SupplierSmartInfo(
      balance: supplier.balance,
      totalInvoices: 0,
      totalAmount: 0,
      lastPurchaseDate: null,
      lastPurchaseAmount: 0,
    );

    // Get purchase history for this supplier
    final purchases =
        await (db.select(db.purchases)
              ..where((p) => p.supplierId.equals(supplier.id))
              ..orderBy([(p) => OrderingTerm.desc(p.date)]))
            .get();

    if (purchases.isNotEmpty) {
      double totalAmount = 0;
      for (var p in purchases) {
        totalAmount += p.total;
      }
      _supplierInfo = SupplierSmartInfo(
        balance: supplier.balance,
        totalInvoices: purchases.length,
        totalAmount: totalAmount,
        lastPurchaseDate: purchases.first.date,
        lastPurchaseAmount: purchases.first.total,
      );
    }

    // Load last purchase prices for each product from this supplier
    await _loadLastPurchasePricesForSupplier(supplier.id);

    notifyListeners();
  }

  /// Get last purchase prices for all products from a supplier
  Future<void> _loadLastPurchasePricesForSupplier(String supplierId) async {
    // Get all products
    final products = await db.select(db.products).get();

    for (var product in products) {
      // Get last purchase of this product from this supplier
      final query =
          db.select(db.purchases).join([
              innerJoin(
                db.purchaseItems,
                db.purchaseItems.purchaseId.equalsExp(db.purchases.id),
              ),
            ])
            ..where(db.purchases.supplierId.equals(supplierId))
            ..where(db.purchaseItems.productId.equals(product.id))
            ..orderBy([OrderingTerm.desc(db.purchases.date)])
            ..limit(1);

      final lastPurchase = await query.getSingleOrNull();

      if (lastPurchase != null) {
        final purchase = lastPurchase.readTable(db.purchases);
        final item = lastPurchase.readTable(db.purchaseItems);

        // Calculate average cost from purchase items
        final avgCost = await _calculateAverageCost(product.id);

        _productInfoCache[product.id] = ProductSmartInfo(
          currentStock: product.stock,
          averageCost: avgCost,
          lastPurchasePrice: item.unitPrice,
          lastPurchaseDate: purchase.date,
          priceHistory: [],
        );
      }
    }
  }

  // ==================== SMART PRODUCT INFO ====================

  /// Load product info when adding a product
  Future<void> loadProductInfo(Product product, {String? supplierId}) async {
    // Get current stock from inventory
    double currentStock = product.stock;

    // Get inventory transactions for this product
    final transactions =
        await (db.select(db.inventoryTransactions)
              ..where((t) => t.productId.equals(product.id))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    // Calculate actual stock from transactions
    double calculatedStock = 0;
    for (var t in transactions) {
      if (t.type == 'PURCHASE' || t.type == 'RETURN_IN') {
        calculatedStock += t.quantity;
      } else if (t.type == 'SALE' || t.type == 'RETURN_OUT') {
        calculatedStock -= t.quantity;
      }
    }
    currentStock = calculatedStock;

    // Calculate average cost
    final avgCost = await _calculateAverageCost(product.id);

    // Get last purchase info
    double? lastPrice;
    DateTime? lastDate;

    final query =
        db.select(db.purchases).join([
            innerJoin(
              db.purchaseItems,
              db.purchaseItems.purchaseId.equalsExp(db.purchases.id),
            ),
          ])
          ..where(db.purchaseItems.productId.equals(product.id))
          ..orderBy([OrderingTerm.desc(db.purchases.date)])
          ..limit(1);

    final lastPurchase = await query.getSingleOrNull();

    if (lastPurchase != null) {
      final purchase = lastPurchase.readTable(db.purchases);
      final item = lastPurchase.readTable(db.purchaseItems);
      lastPrice = item.unitPrice;
      lastDate = purchase.date;
    }

    // Get price history
    final priceHistory = await _getPriceHistory(product.id);

    _productInfoCache[product.id] = ProductSmartInfo(
      currentStock: currentStock,
      averageCost: avgCost,
      lastPurchasePrice: lastPrice ?? product.buyPrice,
      lastPurchaseDate: lastDate,
      priceHistory: priceHistory,
    );

    notifyListeners();
  }

  /// Calculate average cost of a product from all purchases
  Future<double> _calculateAverageCost(String productId) async {
    final items = await (db.select(
      db.purchaseItems,
    )..where((i) => i.productId.equals(productId))).get();

    if (items.isEmpty) return 0;

    double totalCost = 0;
    double totalQty = 0;

    for (var item in items) {
      totalCost += item.unitPrice * item.quantity;
      totalQty += item.quantity;
    }

    return totalQty > 0 ? totalCost / totalQty : 0;
  }

  /// Get price history for a product
  Future<List<ProductPriceHistory>> _getPriceHistory(String productId) async {
    final query =
        db.select(db.purchases).join([
            innerJoin(
              db.purchaseItems,
              db.purchaseItems.purchaseId.equalsExp(db.purchases.id),
            ),
            leftOuterJoin(
              db.suppliers,
              db.suppliers.id.equalsExp(db.purchases.supplierId),
            ),
          ])
          ..where(db.purchaseItems.productId.equals(productId))
          ..orderBy([OrderingTerm.desc(db.purchases.date)])
          ..limit(10);

    final result = await query.get();

    final history = <ProductPriceHistory>[];
    for (var row in result) {
      final purchase = row.readTable(db.purchases);
      final item = row.readTable(db.purchaseItems);
      final supplier = row.readTableOrNull(db.suppliers);

      history.add(
        ProductPriceHistory(
          price: item.unitPrice,
          date: purchase.date,
          supplierName: supplier?.name ?? 'غير محدد',
        ),
      );
    }

    return history;
  }

  // ==================== REAL-TIME ALERTS ====================

  /// Check and generate alerts for current purchase items
  void checkAlerts() {
    _alerts.clear();

    for (var item in items) {
      final productInfo = _productInfoCache[item.product.id];

      if (productInfo != null) {
        // Check if price is higher than average
        if (item.unitPrice > productInfo.averageCost &&
            productInfo.averageCost > 0) {
          final diff =
              ((item.unitPrice - productInfo.averageCost) /
              productInfo.averageCost *
              100);
          if (diff > 10) {
            _alerts.add(
              PurchaseAlert(
                type: PurchaseAlertType.highPrice,
                message:
                    'السعر أعلى من متوسط التكلفة بنسبة ${diff.toStringAsFixed(1)}%',
                isWarning: true,
                productId: item.product.id,
              ),
            );
          }
        }

        // Check if price is significantly lower
        if (item.unitPrice < productInfo.averageCost * 0.7 &&
            productInfo.averageCost > 0) {
          _alerts.add(
            PurchaseAlert(
              type: PurchaseAlertType.lowPrice,
              message: 'السعر أقل بكثير من متوسط التكلفة',
              isWarning: false,
              productId: item.product.id,
            ),
          );
        }

        // Check for large quantity
        if (item.quantity > 100) {
          _alerts.add(
            PurchaseAlert(
              type: PurchaseAlertType.largeQuantity,
              message: 'كمية كبيرة: ${item.quantity}',
              isWarning: true,
              productId: item.product.id,
            ),
          );
        }

        // Check for low stock
        if (productInfo.currentStock < item.product.alertLimit) {
          _alerts.add(
            PurchaseAlert(
              type: PurchaseAlertType.lowStock,
              message: 'مخزون منخفض: ${productInfo.currentStock}',
              isWarning: true,
              productId: item.product.id,
            ),
          );
        }

        // Check for high stock
        if (productInfo.currentStock > item.product.alertLimit * 10) {
          _alerts.add(
            PurchaseAlert(
              type: PurchaseAlertType.highStock,
              message: 'مخزون مرتفع: ${productInfo.currentStock} -可以考虑减少采购',
              isWarning: false,
              productId: item.product.id,
            ),
          );
        }
      }
    }

    notifyListeners();
  }

  /// Update item and recheck alerts
  void updateItemAndCheckAlerts(
    int index, {
    double? quantity,
    double? unitPrice,
    double? discount,
    DateTime? expiry,
    String? batch,
    UnitConversion? unit,
  }) {
    updateItem(
      index,
      quantity: quantity,
      unitPrice: unitPrice,
      discount: discount,
      expiry: expiry,
      batch: batch,
      unit: unit,
    );
    checkAlerts();
  }

  /// Add item and load product info
  Future<void> addItemWithInfo(Product product) async {
    items.add(
      PurchaseItemData(
        product: product,
        unitPrice: product.buyPrice,
        taxPercent: product.taxRate,
      ),
    );

    // Load smart info for this product
    await loadProductInfo(product);

    // Check alerts
    checkAlerts();

    notifyListeners();
  }

  /// Set supplier and load all related info
  Future<void> setSupplier(Supplier? supplier) async {
    selectedSupplier = supplier;
    if (supplier != null) {
      await loadSupplierInfo(supplier);
    }
    notifyListeners();
  }
}
