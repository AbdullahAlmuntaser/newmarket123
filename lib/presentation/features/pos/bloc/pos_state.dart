import 'package:equatable/equatable.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final bool isWholesale;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.isWholesale = false,
  });

  double get unitPrice =>
      isWholesale ? product.wholesalePrice : product.sellPrice;
  double get total => unitPrice * quantity;

  CartItem copyWith({int? quantity, bool? isWholesale}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      isWholesale: isWholesale ?? this.isWholesale,
    );
  }

  @override
  List<Object?> get props => [product, quantity, isWholesale];
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

  const PosLoaded({
    this.cart = const [],
    this.discount = 0,
    this.taxRate = 0,
    this.isWholesaleMode = false,
  });

  double get subtotal => cart.fold(0.0, (sum, item) => sum + item.total);
  double get taxAmount => (subtotal - discount) * taxRate;
  double get total => (subtotal - discount) + taxAmount;

  PosLoaded copyWith({
    List<CartItem>? cart,
    double? discount,
    double? taxRate,
    bool? isWholesaleMode,
  }) {
    return PosLoaded(
      cart: cart ?? this.cart,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      isWholesaleMode: isWholesaleMode ?? this.isWholesaleMode,
    );
  }

  @override
  List<Object?> get props => [cart, discount, taxRate, isWholesaleMode];
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
