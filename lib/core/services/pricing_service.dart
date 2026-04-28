import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:decimal/decimal.dart';

class PricingService {
  final AppDatabase db;

  PricingService(this.db);

  /// Calculates the applicable price for a product based on a specific price list.
  /// Falls back to the product's default sell price if no list price is found.
  Future<Decimal> getPriceForProduct(
    String productId,
    String? priceListId,
    Decimal quantity,
  ) async {
    if (priceListId == null) {
      return await _getDefaultPrice(productId);
    }

    final query = (db.select(db.priceListItems)
      ..where(
        (p) =>
            p.priceListId.equals(priceListId) & p.productId.equals(productId),
      )
      ..orderBy([
        (p) => OrderingTerm(expression: p.minQuantity, mode: OrderingMode.desc),
      ]));

    final items = await query.get();

    for (var item in items) {
      if (quantity >= Decimal.parse(item.minQuantity.toString())) {
        return Decimal.parse(item.price.toString());
      }
    }

    return await _getDefaultPrice(productId);
  }

  Future<Decimal> _getDefaultPrice(String productId) async {
    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingleOrNull();
    return Decimal.parse((product?.sellPrice ?? 0.0).toString());
  }

  /// Integrated price calculation including promotions and customer discounts.
  Future<Decimal> calculatePrice({
    required String productId,
    required Decimal quantity,
    String? priceListId,
    String? customerId,
  }) async {
    // 1. Get base price (from list or product default)
    var finalPrice = await getPriceForProduct(
      productId,
      priceListId,
      quantity,
    );

    // 2. Apply customer-specific discount
    if (customerId != null) {
      final customer = await (db.select(db.customers)..where((c) => c.id.equals(customerId))).getSingleOrNull();
      if (customer != null && customer.discountRate > 0) {
        final customerDiscountFactor = Decimal.parse((customer.discountRate / 100).toString());
        finalPrice -= (finalPrice * customerDiscountFactor);
      }
    }

    // 3. Apply promotions
    finalPrice = await applyPromotions(productId, finalPrice, quantity);

    return finalPrice;
  }

  /// Calculates the final price after applying active promotions.
  Future<Decimal> applyPromotions(
    String productId,
    Decimal basePrice,
    Decimal quantity,
  ) async {
    final now = DateTime.now();
    final activePromotions =
        await (db.select(db.promotions)..where(
              (p) =>
                  p.isActive.equals(true) &
                  p.startDate.isSmallerOrEqual(Variable(now)) &
                  p.endDate.isBiggerOrEqual(Variable(now)) &
                  (p.productId.equals(productId) | p.productId.isNull()),
            ))
            .get();

    Decimal finalPrice = basePrice;
    for (var promo in activePromotions) {
      if (quantity < Decimal.parse(promo.minPurchaseAmount.toString())) {
        continue;
      }

      if (promo.type == 'PERCENTAGE_DISCOUNT') {
        final discountFactor = Decimal.parse((promo.value / 100).toString());
        finalPrice -= (basePrice * discountFactor);
      } else if (promo.type == 'FIXED_DISCOUNT') {
        finalPrice -= Decimal.parse(promo.value.toString());
      }
    }

    return finalPrice > Decimal.zero ? finalPrice : Decimal.zero;
  }
}
