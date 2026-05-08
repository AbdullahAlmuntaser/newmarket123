import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

class PricingLogic {
  static Decimal getPriceForProduct({
    required double defaultPrice,
    List<Map<String, dynamic>>? priceListItems,
    required Decimal quantity,
  }) {
    if (priceListItems == null || priceListItems.isEmpty) {
      return Decimal.parse(defaultPrice.toString());
    }

    final sortedItems = List<Map<String, dynamic>>.from(priceListItems)
      ..sort((a, b) => (b['minQuantity'] as num).compareTo(a['minQuantity'] as num));

    for (var item in sortedItems) {
      if (quantity >= Decimal.parse((item['minQuantity'] as num).toString())) {
        return Decimal.parse((item['price'] as num).toString());
      }
    }

    return Decimal.parse(defaultPrice.toString());
  }

  static Decimal applyPercentageDiscount(Decimal price, double discountPercent) {
    final discountFactor = Decimal.parse((discountPercent / 100).toString());
    return price - (price * discountFactor);
  }

  static Decimal applyFixedDiscount(Decimal price, Decimal fixedAmount) {
    return price - fixedAmount;
  }

  static Decimal calculatePrice({
    required Decimal basePrice,
    double? customerDiscount,
    List<Map<String, dynamic>>? promotions,
    required Decimal quantity,
  }) {
    var finalPrice = basePrice;

    if (customerDiscount != null && customerDiscount > 0) {
      finalPrice = applyPercentageDiscount(finalPrice, customerDiscount);
    }

    if (promotions != null) {
      for (var promo in promotions) {
        final minQty = Decimal.parse((promo['minQuantity'] as num?)?.toString() ?? '0');
        if (quantity < minQty) continue;

        if (promo['type'] == 'PERCENTAGE_DISCOUNT') {
          finalPrice = applyPercentageDiscount(finalPrice, (promo['value'] as num).toDouble());
        } else if (promo['type'] == 'FIXED_DISCOUNT') {
          finalPrice = applyFixedDiscount(finalPrice, Decimal.parse(promo['value'].toString()));
        }
      }
    }

    return finalPrice >= Decimal.zero ? finalPrice : Decimal.zero;
  }
}

void main() {
  group('PricingLogic - getPriceForProduct', () {
    test('returns default price when no price list', () {
      final price = PricingLogic.getPriceForProduct(
        defaultPrice: 50.0,
        quantity: Decimal.one,
      );
      expect(price, equals(Decimal.parse('50')));
    });

    test('returns price based on quantity tier', () {
      final priceList = [
        {'minQuantity': 1, 'price': 50.0},
        {'minQuantity': 10, 'price': 45.0},
        {'minQuantity': 50, 'price': 40.0},
      ];

      final price = PricingLogic.getPriceForProduct(
        defaultPrice: 50.0,
        priceListItems: priceList,
        quantity: Decimal.parse('20'),
      );

      expect(price, equals(Decimal.parse('45')));
    });

    test('returns highest tier price when quantity exceeds all tiers', () {
      final priceList = [
        {'minQuantity': 1, 'price': 50.0},
        {'minQuantity': 10, 'price': 45.0},
      ];

      final price = PricingLogic.getPriceForProduct(
        defaultPrice: 50.0,
        priceListItems: priceList,
        quantity: Decimal.parse('100'),
      );

      expect(price, equals(Decimal.parse('45')));
    });
  });

  group('PricingLogic - applyPercentageDiscount', () {
    test('applies 10% discount correctly', () {
      final price = Decimal.parse('100');
      final discounted = PricingLogic.applyPercentageDiscount(price, 10);
      expect(discounted, equals(Decimal.parse('90')));
    });

    test('price handles large discount', () {
      final price = Decimal.parse('100');
      final discounted = PricingLogic.applyPercentageDiscount(price, 150);
      expect(discounted.toDouble(), lessThan(0));
    });
  });

  group('PricingLogic - calculatePrice', () {
    test('applies customer discount', () {
      final price = PricingLogic.calculatePrice(
        basePrice: Decimal.parse('100'),
        customerDiscount: 15,
        quantity: Decimal.one,
      );
      expect(price, equals(Decimal.parse('85')));
    });

    test('applies promotion discount', () {
      final promotions = [
        {'type': 'PERCENTAGE_DISCOUNT', 'value': 20, 'minQuantity': 1},
      ];

      final price = PricingLogic.calculatePrice(
        basePrice: Decimal.parse('100'),
        promotions: promotions,
        quantity: Decimal.one,
      );

      expect(price.toDouble(), closeTo(80.0, 0.01));
    });

    test('price handles large promotion discount', () {
      final promotions = [
        {'type': 'PERCENTAGE_DISCOUNT', 'value': 200, 'minQuantity': 0},
      ];

      final price = PricingLogic.calculatePrice(
        basePrice: Decimal.parse('100'),
        promotions: promotions,
        quantity: Decimal.one,
      );

      expect(price.toDouble(), lessThanOrEqualTo(0));
    });

    test('does not apply promotion when quantity below minimum', () {
      final promotions = [
        {'type': 'PERCENTAGE_DISCOUNT', 'value': 50, 'minQuantity': 100},
      ];

      final price = PricingLogic.calculatePrice(
        basePrice: Decimal.parse('100'),
        promotions: promotions,
        quantity: Decimal.one,
      );

      expect(price, equals(Decimal.parse('100')));
    });
  });
}
