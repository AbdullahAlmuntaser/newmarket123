import 'package:supermarket/data/datasources/local/app_database.dart';

abstract class AppEvent {}

class SaleCreatedEvent extends AppEvent {
  final Sale sale;
  final List<SaleItem> items;
  final String? userId;

  SaleCreatedEvent(this.sale, this.items, {this.userId});
}

class SaleReturnCreatedEvent extends AppEvent {
  final SalesReturn saleReturn;
  final List<SalesReturnItem> items;
  final String? userId;

  SaleReturnCreatedEvent(this.saleReturn, this.items, {this.userId});
}

class PurchaseCreatedEvent extends AppEvent {
  final Purchase purchase;
  final List<PurchaseItem> items;
  final String? userId;

  PurchaseCreatedEvent(this.purchase, this.items, {this.userId});
}

class PurchasePostedEvent extends AppEvent {
  final Purchase purchase;
  final List<PurchaseItem> items;
  final String? userId;

  PurchasePostedEvent(this.purchase, this.items, {this.userId});
}

class SalePostedEvent extends AppEvent {
  final Sale sale;
  final List<SaleItem> items;
  final String? userId;

  SalePostedEvent(this.sale, this.items, {this.userId});
}

class PurchaseReturnCreatedEvent extends AppEvent {
  final PurchaseReturn purchaseReturn;
  final List<PurchaseReturnItem> items;
  final String? userId;

  PurchaseReturnCreatedEvent(this.purchaseReturn, this.items, {this.userId});
}

class CustomerPaymentEvent extends AppEvent {
  final String customerId;
  final double amount;
  final String paymentMethod;
  final String? note;
  final String paymentId;
  final String? userId;

  CustomerPaymentEvent({
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    this.note,
    required this.paymentId,
    this.userId,
  });
}

class SupplierPaymentEvent extends AppEvent {
  final String supplierId;
  final double amount;
  final String paymentMethod;
  final String? note;
  final String paymentId;
  final String? userId;

  SupplierPaymentEvent({
    required this.supplierId,
    required this.amount,
    required this.paymentMethod,
    this.note,
    required this.paymentId,
    this.userId,
  });
}
