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

class PurchaseReturnCreatedEvent extends AppEvent {
  final PurchaseReturn purchaseReturn;
  final List<PurchaseReturnItem> items;
  final String? userId;

  PurchaseReturnCreatedEvent(this.purchaseReturn, this.items, {this.userId});
}
