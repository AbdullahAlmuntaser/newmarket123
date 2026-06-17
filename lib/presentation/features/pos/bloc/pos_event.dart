import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';

abstract class PosEvent extends Equatable {
  const PosEvent();
  @override
  List<Object?> get props => [];
}

class LoadCategories extends PosEvent {}

class SelectCategory extends PosEvent {
  final String? categoryId;
  const SelectCategory(this.categoryId);
  @override
  List<Object?> get props => [categoryId];
}

class AddProductBySku extends PosEvent {
  final String sku;
  const AddProductBySku(this.sku);
  @override
  List<Object?> get props => [sku];
}

class UpdateCartItemQuantity extends PosEvent {
  final String productId;
  final Decimal quantity;
  const UpdateCartItemQuantity(this.productId, this.quantity);
}

class RemoveCartItem extends PosEvent {
  final String productId;
  const RemoveCartItem(this.productId);
}

class UpdateDiscount extends PosEvent {
  final Decimal discount;
  const UpdateDiscount(this.discount);
}

class UpdateTaxRate extends PosEvent {
  final Decimal taxRate;
  const UpdateTaxRate(this.taxRate);
}

class ToggleWholesaleMode extends PosEvent {
  final bool isWholesale;
  const ToggleWholesaleMode(this.isWholesale);
}

class CheckoutEvent extends PosEvent {
  final String paymentMethod;
  final String? customerId;
  final String? userId;
  final String? currencyId;
  final Decimal exchangeRate;
  CheckoutEvent(
    this.paymentMethod, {
    this.customerId,
    this.userId,
    this.currencyId,
    Decimal? exchangeRate,
  }) : exchangeRate = exchangeRate ?? Decimal.one;
}

class UpdateCartItemUnit extends PosEvent {
  final String productId;
  final String unitName;
  const UpdateCartItemUnit(this.productId, this.unitName);
  @override
  List<Object?> get props => [productId, unitName];
}

class ToggleCartItemUnit extends PosEvent {
  final String productId;
  final bool isCarton;
  const ToggleCartItemUnit(this.productId, this.isCarton);
  @override
  List<Object?> get props => [productId, isCarton];
}

class SearchProducts extends PosEvent {
  final String query;
  const SearchProducts(this.query);
  @override
  List<Object?> get props => [query];
}

class SelectPriceList extends PosEvent {
  final String? priceListId;
  const SelectPriceList(this.priceListId);
  @override
  List<Object?> get props => [priceListId];
}

class ClearCart extends PosEvent {}

class RefreshPricesEvent extends PosEvent {}

// ====== RETURN EVENTS ======

class ToggleReturnMode extends PosEvent {
  final bool isReturnMode;
  const ToggleReturnMode(this.isReturnMode);
}

class LookupOriginalSale extends PosEvent {
  final String saleReference;
  const LookupOriginalSale(this.saleReference);
}

class AddReturnItem extends PosEvent {
  final String productId;
  final String? batchId;
  final Decimal quantity;
  final Decimal unitPrice;
  final String reason;
  const AddReturnItem({
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
    this.reason = '',
  });
}

class RemoveReturnItem extends PosEvent {
  final String productId;
  const RemoveReturnItem(this.productId);
}

class ProcessReturn extends PosEvent {
  final String originalSaleId;
  final String? customerId;
  const ProcessReturn(this.originalSaleId, {this.customerId});
}

class ClearReturn extends PosEvent {}
