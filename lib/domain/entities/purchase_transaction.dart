import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum PurchaseDocStatus { draft, received, completed, returned, cancelled }

class PurchaseTransactionEntity extends Equatable {
  final String id;
  final String? supplierId;
  final Decimal total;
  final Decimal tax;
  final Decimal discount;
  final Decimal landedCosts;
  final Decimal shippingCost;
  final Decimal otherExpenses;
  final String? invoiceNumber;
  final String purchaseType;
  final DateTime date;
  final bool isCredit;
  final PurchaseDocStatus status;
  final String? branchId;
  final List<PurchaseItemEntity> items;

  const PurchaseTransactionEntity({
    required this.id,
    this.supplierId,
    required this.total,
    required this.tax,
    required this.discount,
    required this.landedCosts,
    required this.shippingCost,
    required this.otherExpenses,
    this.invoiceNumber,
    this.purchaseType = 'cash',
    required this.date,
    this.isCredit = false,
    this.status = PurchaseDocStatus.draft,
    this.branchId,
    this.items = const [],
  });

  Decimal get netTotal =>
      total + tax + landedCosts + shippingCost + otherExpenses - discount;

  @override
  List<Object?> get props => [
        id, supplierId, total, tax, discount, landedCosts, shippingCost,
        otherExpenses, invoiceNumber, purchaseType, date, isCredit,
        status, branchId, items,
      ];
}

class PurchaseItemEntity extends Equatable {
  final String id;
  final String purchaseId;
  final String productId;
  final Decimal quantity;
  final Decimal quantityInBaseUnit;
  final Decimal unitPrice;
  final Decimal price;
  final Decimal discount;
  final Decimal discountPercent;
  final Decimal tax;
  final Decimal taxPercent;
  final Decimal landedCostShare;
  final String? unitId;
  final String? unitName;
  final Decimal unitFactor;

  const PurchaseItemEntity({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.quantityInBaseUnit,
    required this.unitPrice,
    required this.price,
    required this.discount,
    required this.discountPercent,
    required this.tax,
    required this.taxPercent,
    required this.landedCostShare,
    this.unitId,
    this.unitName,
    required this.unitFactor,
  });

  Decimal get subtotal => quantity * price;
  Decimal get netTotal => subtotal + tax - discount;

  @override
  List<Object?> get props => [
        id, purchaseId, productId, quantity, quantityInBaseUnit,
        unitPrice, price, discount, discountPercent, tax, taxPercent,
        landedCostShare, unitId, unitName, unitFactor,
      ];
}
