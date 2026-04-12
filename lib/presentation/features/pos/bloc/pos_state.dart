import 'package:equatable/equatable.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final bool isWholesale;
  final String unitName; // الاسم الحالي للوحدة (حبة، كرتون، إلخ)
  final double unitFactor; // المعامل الخاص بالوحدة المختارة
  final double unitPrice;
  final List<UnitConversion> availableUnits; // قائمة بكل الوحدات المتاحة لهذا المنتج

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.isWholesale = false,
    this.unitName = 'حبة',
    this.unitFactor = 1.0,
    this.unitPrice = 0.0,
    this.availableUnits = const [],
  });

  double get total => unitPrice * quantity;

  CartItem copyWith({
    int? quantity,
    bool? isWholesale,
    String? unitName,
    double? unitFactor,
    double? unitPrice,
    List<UnitConversion>? availableUnits,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      isWholesale: isWholesale ?? this.isWholesale,
      unitName: unitName ?? this.unitName,
      unitFactor: unitFactor ?? this.unitFactor,
      unitPrice: unitPrice ?? this.unitPrice,
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
  final double discount;
  final double taxRate; // e.g. 0.15 for 15%
  final bool isWholesaleMode;
  final List<Product> searchResults;
  final List<Category> categories;
  final String? selectedCategoryId;
  final List<Product> filteredProducts;
  final String? activePriceListId; // New field

  const PosLoaded({
    this.cart = const [],
    this.discount = 0,
    this.taxRate = 0,
    this.isWholesaleMode = false,
    this.searchResults = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.filteredProducts = const [],
    this.activePriceListId,
  });

  double get subtotal => cart.fold(0.0, (sum, item) => sum + item.total);
  double get taxAmount => (subtotal - discount) * taxRate;
  double get total => (subtotal - discount) + taxAmount;

  PosLoaded copyWith({
    List<CartItem>? cart,
    double? discount,
    double? taxRate,
    bool? isWholesaleMode,
    List<Product>? searchResults,
    List<Category>? categories,
    String? selectedCategoryId,
    List<Product>? filteredProducts,
    String? activePriceListId,
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
  ];
}

class PosError extends PosState {
  final String message;
  const PosError(this.message);
}

class PosCheckoutSuccess extends PosState {
  final Sale sale;
  final List<SaleItem> items;
  final List<Product> products; // Need products for names/etc.
  const PosCheckoutSuccess(this.sale, this.items, this.products);

  @override
  List<Object?> get props => [sale, items, products];
}
