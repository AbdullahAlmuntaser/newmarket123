import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CartItem extends Equatable {
  final Product product;
  final Decimal quantity;
  final bool isWholesale;
  final String unitName; // الاسم الحالي للوحدة (حبة، كرتون، إلخ)
  final Decimal unitFactor; // المعامل الخاص بالوحدة المختارة
  final Decimal unitPrice;
  final List<UnitConversion> availableUnits; // قائمة بكل الوحدات المتاحة لهذا المنتج

  const CartItem({
    required this.product,
    required this.quantity,
    this.isWholesale = false,
    this.unitName = 'حبة',
    required this.unitFactor,
    required this.unitPrice,
    this.availableUnits = const [],
  });

  Decimal get total => unitPrice * quantity;

  CartItem copyWith({
    Decimal? quantity,
    bool? isWholesale,
    String? unitName,
    Decimal? unitFactor,
    Decimal? unitPrice,
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
  final Decimal discount;
  final Decimal taxRate; // e.g. 0.15 for 15%
  final bool isWholesaleMode;
  final List<Product> searchResults;
  final List<Category> categories;
  final String? selectedCategoryId;
  final List<Product> filteredProducts;
  final String? activePriceListId; // New field

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
  })  : discount = discount ?? Decimal.zero,
        taxRate = taxRate ?? Decimal.zero;

  Decimal get subtotal => cart.fold(Decimal.zero, (sum, item) => sum + item.total);
  Decimal get taxAmount => (subtotal - discount) * taxRate;
  Decimal get total => (subtotal - discount) + taxAmount;

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
