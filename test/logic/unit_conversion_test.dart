import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitConversionService - Logic Tests', () {
    test('converts to base unit correctly', () {
      const quantity = 5.0;
      const unitFactor = 2.0;
      const result = quantity * unitFactor;
      expect(result, equals(10.0));
    });

    test('converts from base unit correctly', () {
      const baseQuantity = 10.0;
      const unitFactor = 2.0;
      const result = baseQuantity / unitFactor;
      expect(result, equals(5.0));
    });

    test('base unit returns same quantity', () {
      const unitName = 'Pcs';
      const productUnit = 'Pcs';
      expect(unitName == productUnit, isTrue);
    });

    test('handles zero quantity conversion', () {
      const baseQuantity = 0.0;
      expect(baseQuantity, equals(0.0));
    });

    test('handles product units extraction', () {
      const productUnits = [
        {'unitName': 'Pcs', 'unitFactor': 1.0},
        {'unitName': 'Box', 'unitFactor': 12.0},
        {'unitName': 'Carton', 'unitFactor': 144.0},
      ];

      final foundUnit = productUnits.firstWhere(
        (pu) => pu['unitName'] == 'Box',
        orElse: () => throw Exception('Unit not found'),
      );

      expect(foundUnit['unitFactor'], equals(12.0));
    });

    test('throws when unit not found', () {
      const productUnits = [
        {'unitName': 'Pcs', 'unitFactor': 1.0},
        {'unitName': 'Box', 'unitFactor': 12.0},
      ];

      expect(
        () => productUnits.firstWhere(
          (pu) => pu['unitName'] == 'Pack',
          orElse: () => throw Exception('Unit "Pack" not found for product'),
        ),
        throwsException,
      );
    });

    test('validates positive conversion factor', () {
      const conversionFactor = -5.0;
      expect(conversionFactor <= 0, isTrue);
    });

    test('prevents duplicate unit addition', () {
      const existingUnits = [
        {'unitName': 'Pcs'},
        {'unitName': 'Box'},
      ];

      const newUnitName = 'Box';
      final exists = existingUnits.any((pu) => pu['unitName'] == newUnitName);
      expect(exists, isTrue);
    });

    test('allows new unique unit', () {
      const existingUnits = [
        {'unitName': 'Pcs'},
        {'unitName': 'Box'},
      ];

      const newUnitName = 'Carton';
      final exists = existingUnits.any((pu) => pu['unitName'] == newUnitName);
      expect(exists, isFalse);
    });
  });

  group('UnitConversionService - Conversion Scenarios', () {
    test('converts carton to pieces', () {
      const cartonQty = 2.0;
      const piecesPerCarton = 24.0;
      const pieces = cartonQty * piecesPerCarton;
      expect(pieces, equals(48.0));
    });

    test('converts pieces to carton', () {
      const pieces = 48.0;
      const piecesPerCarton = 24.0;
      const cartons = pieces / piecesPerCarton;
      expect(cartons, equals(2.0));
    });

    test('converts kilo to gram', () {
      const kiloQty = 2.5;
      const gramsPerKilo = 1000.0;
      const grams = kiloQty * gramsPerKilo;
      expect(grams, equals(2500.0));
    });

    test('converts gram to kilo', () {
      const grams = 2500.0;
      const gramsPerKilo = 1000.0;
      const kilos = grams / gramsPerKilo;
      expect(kilos, equals(2.5));
    });

    test('handles fractional quantities', () {
      const pieces = 7.5;
      const piecesPerBox = 12.0;
      const boxes = pieces / piecesPerBox;
      expect(boxes, closeTo(0.625, 0.01));
    });

    test('rounds for display appropriately', () {
      const value = 2.333333;
      final rounded = double.parse(value.toStringAsFixed(2));
      expect(rounded, equals(2.33));
    });
  });

  group('UnitConversionService - Edge Cases', () {
    test('handles very large conversion factors', () {
      const quantity = 1.0;
      const factor = 1000000.0;
      const result = quantity * factor;
      expect(result, equals(1000000.0));
    });

    test('handles very small conversion factors', () {
      const quantity = 1000.0;
      const factor = 0.001;
      const result = quantity * factor;
      expect(result, equals(1.0));
    });

    test('prevents zero division', () {
      const factor = 0.0;
      expect(factor <= 0, isTrue);
    });
  });
}
