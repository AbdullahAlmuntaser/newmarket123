import 'package:equatable/equatable.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CartItem extends Equatable {
  final Product product;
  final Decimal quantity;
  final bool isWholesale;
  final String unitName; // الاسم الحالي للوحدة (حبة، كرتون، إلخ)
  final Decimal unitFactor; // المعامل الخاص بالوحدة المختارة
  final Decimal unitPrice;
  final Decimal? discount;
  final List<ProductUnit>
      availableUnits; // قائمة بكل الوحدات المتاحة لهذا المنتج

  const CartItem({
    required this.product,
    required this.quantity,
    this.isWholesale = false,
    this.unitName = 'حبة',
    required this.unitFactor,
    required this.unitPrice,
    this.discount,
    this.availableUnits = const [],
  });

  Decimal get total => (unitPrice * quantity) - (discount ?? Decimal.zero);

  CartItem copyWith({
    Decimal? quantity,
    bool? isWholesale,
    String? unitName,
    Decimal? unitFactor,
    Decimal? unitPrice,
    Decimal? discount,
    List<ProductUnit>? availableUnits,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      isWholesale: isWholesale ?? this.isWholesale,
      unitName: unitName ?? this.unitName,
      unitFactor: unitFactor ?? this.unitFactor,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      availableUnits: availableUnits ?? this.availableUnits,
    );
  }

  @override
  List<Object?> get props => [
        product,
        quantity,
        isWholesale,
        unitName,
        unitFactor,
        unitPrice,
        discount,
        availableUnits,
      ];
}

abstract class PosState extends Equatable {
  const PosState();
  @override
  List<Object?> get props => [];
}

class PosInitial extends PosState {}

class PosLoading extends PosState {}

class PosLoaded extends PosState {
  final List<CartItem> cart;
  final Decimal discount;
  final Decimal taxRate;
  final bool isWholesaleMode;
  final List<Product> searchResults;
  final List<Category> categories;
  final String? selectedCategoryId;
  final List<Product> filteredProducts;
  final String? activePriceListId;
  final bool isProcessingCheckout;
  final bool isReturnMode;
  final Sale? originalSale;
  final List<ReturnItem> returnItems;
  final List<List<CartItem>> heldSales;

  PosLoaded({
    this.cart = const [],
    Decimal? discount,
    Decimal? taxRate,
    this.isWholesaleMode = false,
    this.searchResults = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.filteredProducts = const [],
    this.activePriceListId,
    this.isProcessingCheckout = false,
    this.isReturnMode = false,
    this.originalSale,
    this.returnItems = const [],
    this.heldSales = const [],
  })  : discount = discount ?? Decimal.zero,
        taxRate = taxRate ?? Decimal.zero;

  Decimal get subtotal =>
      cart.fold(Decimal.zero, (sum, item) => sum + item.total);
  Decimal get taxAmount => (subtotal - discount) * taxRate;
  Decimal get total => (subtotal - discount) + taxAmount;

  Decimal get returnTotal =>
      returnItems.fold(Decimal.zero, (sum, item) => sum + item.total);

  PosLoaded copyWith({
    List<CartItem>? cart,
    Decimal? discount,
    Decimal? taxRate,
    bool? isWholesaleMode,
    List<Product>? searchResults,
    List<Category>? categories,
    String? selectedCategoryId,
    List<Product>? filteredProducts,
    String? activePriceListId,
    bool? isProcessingCheckout,
    bool? isReturnMode,
    Sale? originalSale,
    List<ReturnItem>? returnItems,
    List<List<CartItem>>? heldSales,
    bool clearOriginalSale = false,
  }) {
    return PosLoaded(
      cart: cart ?? this.cart,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      isWholesaleMode: isWholesaleMode ?? this.isWholesaleMode,
      searchResults: searchResults ?? this.searchResults,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      activePriceListId: activePriceListId ?? this.activePriceListId,
      isProcessingCheckout: isProcessingCheckout ?? this.isProcessingCheckout,
      isReturnMode: isReturnMode ?? this.isReturnMode,
      originalSale:
          clearOriginalSale ? null : (originalSale ?? this.originalSale),
      returnItems: returnItems ?? this.returnItems,
      heldSales: heldSales ?? this.heldSales,
    );
  }

  @override
  List<Object?> get props => [
        cart,
        discount,
        taxRate,
        isWholesaleMode,
        searchResults,
        categories,
        selectedCategoryId,
        filteredProducts,
        activePriceListId,
        isProcessingCheckout,
        isReturnMode,
        originalSale,
        returnItems,
        heldSales,
      ];
}

class ReturnItem extends Equatable {
  final String productId;
  final String? batchId;
  final Decimal quantity;
  final Decimal unitPrice;
  final String reason;

  const ReturnItem({
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
    this.reason = '',
  });

  Decimal get total => quantity * unitPrice;

  ReturnItem copyWith({Decimal? quantity, String? reason}) => ReturnItem(
        productId: productId,
        batchId: batchId,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice,
        reason: reason ?? this.reason,
      );

  @override
  List<Object?> get props => [productId, batchId, quantity, unitPrice, reason];
}

class PosError extends PosState {
  final String message;
  const PosError(this.message);
}

class PosCheckoutSuccess extends PosState {
  final Sale sale;
  final List<SaleItem> items;
  final List<Product> products;
  const PosCheckoutSuccess(this.sale, this.items, this.products);

  @override
  List<Object?> get props => [sale, items, products];
}

class PosReturnSuccess extends PosState {
  final String returnId;
  final Sale originalSale;
  final Decimal totalRefund;
  const PosReturnSuccess(this.returnId, this.originalSale, this.totalRefund);

  @override
  List<Object?> get props => [returnId, originalSale, totalRefund];
}
