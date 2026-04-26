import 'package:equatable/equatable.dart';

enum PurchaseStatus { draft, approved, received, completed }

class PurchaseOrder extends Equatable {
  final String id;
  final String supplierId;
  final List<PurchaseItem> items;
  final PurchaseStatus status;
  final DateTime date;
  final double totalAmount;

  const PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.items,
    required this.status,
    required this.date,
    required this.totalAmount,
  });

  @override
  List<Object?> get props => [id, supplierId, items, status, date, totalAmount];
}

class PurchaseItem extends Equatable {
  final String itemId;
  final double quantity;
  final double price;

  const PurchaseItem({
    required this.itemId,
    required this.quantity,
    required this.price,
  });

  @override
  List<Object?> get props => [itemId, quantity, price];
}
