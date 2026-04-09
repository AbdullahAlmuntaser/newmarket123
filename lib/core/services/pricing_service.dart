import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

class PricingService {
  final AppDatabase db;

  PricingService(this.db);

  /// Calculates the applicable price for a product based on a specific price list.
  /// Falls back to the product's default sell price if no list price is found.
  Future<double> getPriceForProduct(
    String productId,
    String? priceListId,
    double quantity,
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
      if (quantity >= item.minQuantity) {
        return item.price;
      }
    }

    return await _getDefaultPrice(productId);
  }

  Future<double> _getDefaultPrice(String productId) async {
    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingleOrNull();
    return product?.sellPrice ?? 0.0;
  }

  /// Calculates the final price after applying active promotions.
  Future<double> applyPromotions(
    String productId,
    double basePrice,
    double quantity,
  ) async {
    final now = DateTime.now();
    final activePromotions =
        await (db.select(db.promotions)..where(
              (p) =>
                  p.isActive.equals(true) &
                  p.startDate.isSmallerOrEqualValue(now) &
                  p.endDate.isBiggerOrEqualValue(now) &
                  (p.productId.equals(productId) | p.productId.isNull()),
            ))
            .get();

    double finalPrice = basePrice;
    for (var promo in activePromotions) {
      if (quantity < promo.minPurchaseAmount) continue;

      if (promo.type == 'PERCENTAGE_DISCOUNT') {
        finalPrice -= (basePrice * (promo.value / 100));
      } else if (promo.type == 'FIXED_DISCOUNT') {
        finalPrice -= promo.value;
      }
    }

    return finalPrice > 0 ? finalPrice : 0.0;
  }
}
