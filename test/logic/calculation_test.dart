import 'package:flutter_test/flutter_test.dart';

class TaxCalculator {
  static double calculateTax(double amount, double taxRate) {
    if (amount < 0 || taxRate < 0) return 0;
    return amount * (taxRate / 100);
  }

  static double calculateTaxInclusive(double totalWithTax, double taxRate) {
    if (taxRate <= 0) return totalWithTax;
    return totalWithTax / (1 + (taxRate / 100));
  }

  static double calculateTaxFromGross(double grossAmount, double taxRate) {
    if (taxRate <= 0) return 0;
    return grossAmount - (grossAmount / (1 + (taxRate / 100)));
  }
}

class DiscountCalculator {
  static double calculateDiscount(double amount, double discountPercent) {
    if (amount < 0 || discountPercent < 0 || discountPercent > 100) return 0;
    return amount * (discountPercent / 100);
  }

  static double applyDiscount(double amount, double discountPercent) {
    return amount - calculateDiscount(amount, discountPercent);
  }

  static double calculateNetAmount({
    required double grossAmount,
    double discountPercent = 0,
    double discountFixed = 0,
    double taxRate = 0,
  }) {
    double net = grossAmount;
    net -= calculateDiscount(net, discountPercent);
    net -= discountFixed;
    if (net < 0) net = 0;
    net += TaxCalculator.calculateTax(net, taxRate);
    return net;
  }
}

class InvoiceCalculator {
  static double calculateSubtotal(List<Map<String, dynamic>> items) {
    double subtotal = 0;
    for (var item in items) {
      final quantity = (item['quantity'] as num).toDouble();
      final price = (item['price'] as num).toDouble();
      final unitFactor = (item['unitFactor'] as num?)?.toDouble() ?? 1.0;
      subtotal += quantity * price * unitFactor;
    }
    return subtotal;
  }

  static double calculateTotal({
    required double subtotal,
    double discountPercent = 0,
    double discountFixed = 0,
    double taxRate = 0,
    double shippingCost = 0,
    double otherExpenses = 0,
  }) {
    double total = subtotal;
    total -= DiscountCalculator.calculateDiscount(total, discountPercent);
    total -= discountFixed;
    if (total < 0) total = 0;
    total += TaxCalculator.calculateTax(total, taxRate);
    total += shippingCost;
    total += otherExpenses;
    return total;
  }

  static Map<String, double> calculateInvoiceAmounts({
    required List<Map<String, dynamic>> items,
    double discountPercent = 0,
    double discountFixed = 0,
    double taxRate = 15,
    double shippingCost = 0,
    double otherExpenses = 0,
  }) {
    final subtotal = calculateSubtotal(items);
    final discountAmount = DiscountCalculator.calculateDiscount(subtotal, discountPercent) + discountFixed;
    final taxableAmount = subtotal - discountAmount;
    final tax = TaxCalculator.calculateTax(taxableAmount > 0 ? taxableAmount : 0, taxRate);
    final total = subtotal - discountAmount + tax + shippingCost + otherExpenses;

    return {
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'tax': tax,
      'total': total > 0 ? total : 0,
    };
  }
}

void main() {
  group('TaxCalculator', () {
    test('calculates tax correctly for positive values', () {
      expect(TaxCalculator.calculateTax(100, 15), equals(15));
      expect(TaxCalculator.calculateTax(200, 10), equals(20));
      expect(TaxCalculator.calculateTax(1000, 5), equals(50));
    });

    test('returns 0 for negative amount', () {
      expect(TaxCalculator.calculateTax(-100, 15), equals(0));
    });

    test('returns 0 for negative tax rate', () {
      expect(TaxCalculator.calculateTax(100, -5), equals(0));
    });

    test('returns 0 for zero amount', () {
      expect(TaxCalculator.calculateTax(0, 15), equals(0));
    });

    test('calculates tax from gross (tax inclusive)', () {
      final result = TaxCalculator.calculateTaxFromGross(115, 15);
      expect(result, closeTo(15, 0.01));
    });

    test('calculates tax from gross with 0 rate', () {
      expect(TaxCalculator.calculateTaxFromGross(100, 0), equals(0));
    });
  });

  group('DiscountCalculator', () {
    test('calculates percentage discount correctly', () {
      expect(DiscountCalculator.calculateDiscount(100, 10), equals(10));
      expect(DiscountCalculator.calculateDiscount(200, 15), equals(30));
      expect(DiscountCalculator.calculateDiscount(1000, 5), equals(50));
    });

    test('returns 0 for discount > 100', () {
      expect(DiscountCalculator.calculateDiscount(100, 150), equals(0));
    });

    test('returns 0 for negative amount', () {
      expect(DiscountCalculator.calculateDiscount(-100, 10), equals(0));
    });

    test('applies discount and returns net amount', () {
      expect(DiscountCalculator.applyDiscount(100, 10), equals(90));
      expect(DiscountCalculator.applyDiscount(200, 15), equals(170));
    });

    test('calculates net amount with all parameters', () {
      final net = DiscountCalculator.calculateNetAmount(
        grossAmount: 1000,
        discountPercent: 10,
        discountFixed: 50,
        taxRate: 15,
      );
      expect(net, closeTo(977.5, 0.01));
    });

    test('handles zero gross amount', () {
      final net = DiscountCalculator.calculateNetAmount(
        grossAmount: 0,
        discountPercent: 10,
        taxRate: 15,
      );
      expect(net, equals(0));
    });
  });

  group('InvoiceCalculator', () {
    test('calculates subtotal for single item', () {
      final items = [
        {'quantity': 2.0, 'price': 50.0, 'unitFactor': 1.0},
      ];
      expect(InvoiceCalculator.calculateSubtotal(items), equals(100));
    });

    test('calculates subtotal for multiple items', () {
      final items = [
        {'quantity': 2.0, 'price': 50.0, 'unitFactor': 1.0},
        {'quantity': 3.0, 'price': 30.0, 'unitFactor': 1.0},
        {'quantity': 1.0, 'price': 100.0, 'unitFactor': 2.0},
      ];
      expect(InvoiceCalculator.calculateSubtotal(items), equals(390));
    });

    test('calculates subtotal with unit factors', () {
      final items = [
        {'quantity': 5.0, 'price': 10.0, 'unitFactor': 2.0},
        {'quantity': 2.0, 'price': 25.0, 'unitFactor': 3.0},
      ];
      expect(InvoiceCalculator.calculateSubtotal(items), equals(250));
    });

    test('calculates total with discount and tax', () {
      final total = InvoiceCalculator.calculateTotal(
        subtotal: 1000,
        discountPercent: 10,
        taxRate: 15,
      );
      expect(total, closeTo(1035, 0.01));
    });

    test('calculates total with fixed discount', () {
      final total = InvoiceCalculator.calculateTotal(
        subtotal: 1000,
        discountFixed: 100,
        taxRate: 15,
      );
      expect(total, closeTo(1035, 0.01));
    });

    test('calculates total with shipping and expenses', () {
      final total = InvoiceCalculator.calculateTotal(
        subtotal: 1000,
        shippingCost: 50,
        otherExpenses: 25,
        taxRate: 15,
      );
      expect(total, closeTo(1225, 0.01));
    });

    test('calculates invoice amounts returns all values', () {
      final items = [
        {'quantity': 10.0, 'price': 100.0, 'unitFactor': 1.0},
      ];
      final amounts = InvoiceCalculator.calculateInvoiceAmounts(
        items: items,
        discountPercent: 10,
        taxRate: 15,
      );

      expect(amounts['subtotal'], equals(1000));
      expect(amounts['discountAmount'], equals(100));
      expect(amounts['taxableAmount'], equals(900));
      expect(amounts['tax'], closeTo(135, 0.01));
      expect(amounts['total'], closeTo(1035, 0.01));
    });

    test('handles empty items list', () {
      final amounts = InvoiceCalculator.calculateInvoiceAmounts(
        items: [],
        taxRate: 15,
      );
      expect(amounts['subtotal'], equals(0));
      expect(amounts['total'], equals(0));
    });

    test('total never goes negative', () {
      final items = [
        {'quantity': 1.0, 'price': 10.0, 'unitFactor': 1.0},
      ];
      final amounts = InvoiceCalculator.calculateInvoiceAmounts(
        items: items,
        discountPercent: 200,
        taxRate: 15,
      );
      expect(amounts['total'], greaterThanOrEqualTo(0));
    });
  });

  group('Edge Cases', () {
    test('handles very large numbers', () {
      final items = [
        {'quantity': 999999.0, 'price': 999999.0, 'unitFactor': 1.0},
      ];
      expect(InvoiceCalculator.calculateSubtotal(items), equals(999998000001.0));
    });

    test('handles decimal quantities', () {
      final items = [
        {'quantity': 0.5, 'price': 100.0, 'unitFactor': 1.0},
        {'quantity': 1.5, 'price': 50.0, 'unitFactor': 1.0},
      ];
      expect(InvoiceCalculator.calculateSubtotal(items), equals(125));
    });

    test('handles very small discount percentages', () {
      final discount = DiscountCalculator.calculateDiscount(1000, 0.01);
      expect(discount, equals(0.1));
    });

    test('handles zero tax rate', () {
      final total = InvoiceCalculator.calculateTotal(
        subtotal: 1000,
        taxRate: 0,
      );
      expect(total, equals(1000));
    });
  });
}
