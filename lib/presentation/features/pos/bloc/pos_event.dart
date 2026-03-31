import 'package:equatable/equatable.dart';

abstract class PosEvent extends Equatable {
  const PosEvent();
  @override
  List<Object?> get props => [];
}

class AddProductBySku extends PosEvent {
  final String sku;
  const AddProductBySku(this.sku);
  @override
  List<Object?> get props => [sku];
}

class UpdateCartItemQuantity extends PosEvent {
  final String productId;
  final int quantity;
  const UpdateCartItemQuantity(this.productId, this.quantity);
}

class RemoveCartItem extends PosEvent {
  final String productId;
  const RemoveCartItem(this.productId);
}

class UpdateDiscount extends PosEvent {
  final double discount;
  const UpdateDiscount(this.discount);
}

class UpdateTaxRate extends PosEvent {
  final double taxRate;
  const UpdateTaxRate(this.taxRate);
}

class ToggleWholesaleMode extends PosEvent {
  final bool isWholesale;
  const ToggleWholesaleMode(this.isWholesale);
}

class CheckoutEvent extends PosEvent {
  final String paymentMethod;
  final String? customerId;
  const CheckoutEvent(this.paymentMethod, {this.customerId});
}

class ClearCart extends PosEvent {}
