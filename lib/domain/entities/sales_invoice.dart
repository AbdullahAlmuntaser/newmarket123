import 'package:equatable/equatable.dart';

class SalesInvoice extends Equatable {
  final String id;
  final String customerId;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String paymentMethod;
  final DateTime timestamp;
  final String qrCodeData;

  const SalesInvoice({
    required this.id,
    required this.customerId,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.timestamp,
    required this.qrCodeData,
  });

  @override
  List<Object?> get props => [
    id,
    customerId,
    items,
    subtotal,
    taxAmount,
    totalAmount,
    paymentMethod,
    timestamp,
    qrCodeData,
  ];
}

class InvoiceItem extends Equatable {
  final String itemId;
  final double quantity;
  final double price;

  const InvoiceItem({
    required this.itemId,
    required this.quantity,
    required this.price,
  });

  @override
  List<Object?> get props => [itemId, quantity, price];
}
