import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum SaleStatus { draft, completed, returned, cancelled }
enum SaleType { retail, wholesale }

class SalesTransaction extends Equatable {
  final String id;
  final String? customerId;
  final Decimal total;
  final Decimal discount;
  final Decimal tax;
  final int paymentMethod;
  final bool isCredit;
  final SaleStatus status;
  final SaleType saleType;
  final String? currencyId;
  final Decimal exchangeRate;
  final Decimal shippingCost;
  final Decimal otherExpenses;
  final String? warehouseId;
  final String? representativeId;
  final DateTime? exchangeDate;
  final String? qrCode;
  final String? hash;
  final String? signature;
  final DateTime createdAt;
  final String? branchId;
  final List<SaleItemEntity> items;

  const SalesTransaction({
    required this.id,
    this.customerId,
    required this.total,
    required this.discount,
    required this.tax,
    this.paymentMethod = 0,
    this.isCredit = false,
    this.status = SaleStatus.draft,
    this.saleType = SaleType.retail,
    this.currencyId,
    required this.exchangeRate,
    required this.shippingCost,
    required this.otherExpenses,
    this.warehouseId,
    this.representativeId,
    this.exchangeDate,
    this.qrCode,
    this.hash,
    this.signature,
    required this.createdAt,
    this.branchId,
    this.items = const [],
  });

  @override
  List<Object?> get props => [
        id, customerId, total, discount, tax, paymentMethod, isCredit,
        status, saleType, currencyId, exchangeRate, shippingCost,
        otherExpenses, warehouseId, representativeId, exchangeDate,
        qrCode, hash, signature, createdAt, branchId, items,
      ];
}

class SaleItemEntity extends Equatable {
  final String id;
  final String saleId;
  final String productId;
  final Decimal quantity;
  final Decimal price;
  final String? unitId;
  final String unitName;
  final Decimal unitFactor;
  final String? warehouseId;
  final String? batchId;
  final String? costCenterId;

  const SaleItemEntity({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.price,
    this.unitId,
    this.unitName = 'حبة',
    required this.unitFactor,
    this.warehouseId,
    this.batchId,
    this.costCenterId,
  });

  Decimal get subtotal => quantity * price;

  @override
  List<Object?> get props => [
        id, saleId, productId, quantity, price, unitId, unitName,
        unitFactor, warehouseId, batchId, costCenterId,
      ];
}
