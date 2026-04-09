import 'package:equatable/equatable.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final bool isWholesale;
  final bool isCarton;
  final double unitPrice;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.isWholesale = false,
    this.isCarton = false,
    this.unitPrice = 0.0,
  });

  double get total => unitPrice * quantity;

  CartItem copyWith({
    int? quantity,
    bool? isWholesale,
    bool? isCarton,
    double? unitPrice,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      isWholesale: isWholesale ?? this.isWholesale,
      isCarton: isCarton ?? this.isCarton,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  @override
  List<Object?> get props => [
    product,
    quantity,
    isWholesale,
    isCarton,
    unitPrice,
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
