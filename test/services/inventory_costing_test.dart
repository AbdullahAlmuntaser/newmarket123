import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';

class BatchInfo {
  final String id;
  final double quantity;
  final double costPrice;
  final DateTime createdAt;
  final DateTime? expiryDate;

  BatchInfo({
    required this.id,
    required this.quantity,
    required this.costPrice,
    required this.createdAt,
    this.expiryDate,
  });
}

class InventoryCostingCalculator {
  static double calculateAverageCost(List<BatchInfo> batches) {
    if (batches.isEmpty) return 0.0;

    double totalValue = 0.0;
    double totalQty = 0.0;

    for (var batch in batches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    return totalQty > 0 ? totalValue / totalQty : 0.0;
  }

  static List<BatchInfo> sortFifo(List<BatchInfo> batches) {
    return List<BatchInfo>.from(batches)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static List<BatchInfo> sortLifo(List<BatchInfo> batches) {
    return List<BatchInfo>.from(batches)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static List<BatchInfo> sortByExpiryWithFifo(List<BatchInfo> batches) {
    return List<BatchInfo>.from(batches)
      ..sort((a, b) {
        if (a.expiryDate == null && b.expiryDate == null) {
          return a.createdAt.compareTo(b.createdAt);
        }
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });
  }

  static double calculateCogs(
    List<BatchInfo> batches,
    double quantityNeeded,
    InventoryValuationMethod method,
  ) {
    List<BatchInfo> sortedBatches;
    switch (method) {
      case InventoryValuationMethod.avco:
        return calculateAverageCost(batches) * quantityNeeded;
      case InventoryValuationMethod.lifo:
        sortedBatches = sortLifo(batches);
        break;
      case InventoryValuationMethod.fifo:
      default:
        sortedBatches = sortByExpiryWithFifo(batches);
    }

    double remaining = quantityNeeded;
    double totalCogs = 0.0;

    for (var batch in sortedBatches) {
      if (remaining <= 0) break;
      if (batch.quantity <= 0) continue;

      final deduct =
          remaining > batch.quantity ? batch.quantity : remaining;
      totalCogs += deduct * batch.costPrice;
      remaining -= deduct;
    }

    return totalCogs;
  }

  static Map<String, double> getInventoryValuation(
    List<BatchInfo> batches,
    InventoryValuationMethod method,
  ) {
    final validBatches = batches.where((b) => b.quantity > 0).toList();

    if (validBatches.isEmpty) {
      return {
        'totalQuantity': 0.0,
        'averageCost': 0.0,
        'totalValue': 0.0,
      };
    }

    double totalValue = 0.0;
    double totalQty = 0.0;

    for (var batch in validBatches) {
      totalValue += batch.quantity * batch.costPrice;
      totalQty += batch.quantity;
    }

    final avgCost = totalQty > 0 ? totalValue / totalQty : 0.0;

    return {
      'totalQuantity': totalQty,
      'averageCost': avgCost,
      'totalValue': totalValue,
    };
  }
}

void main() {
  group('InventoryCostingCalculator - AVCO', () {
    test('calculates average cost correctly', () {
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: DateTime.now()),
        BatchInfo(id: 'b2', quantity: 20, costPrice: 15.0, createdAt: DateTime.now()),
        BatchInfo(id: 'b3', quantity: 30, costPrice: 20.0, createdAt: DateTime.now()),
      ];

      final avgCost = InventoryCostingCalculator.calculateAverageCost(batches);
      expect(avgCost, closeTo(16.67, 0.01));
    });

    test('returns zero for empty batches', () {
      final avgCost = InventoryCostingCalculator.calculateAverageCost([]);
      expect(avgCost, equals(0.0));
    });

    test('handles single batch', () {
      final batches = [
        BatchInfo(id: 'b1', quantity: 100, costPrice: 25.0, createdAt: DateTime.now()),
      ];

      final avgCost = InventoryCostingCalculator.calculateAverageCost(batches);
      expect(avgCost, equals(25.0));
    });

    test('handles batch with zero quantity', () {
      final batches = [
        BatchInfo(id: 'b1', quantity: 0, costPrice: 10.0, createdAt: DateTime.now()),
        BatchInfo(id: 'b2', quantity: 50, costPrice: 20.0, createdAt: DateTime.now()),
      ];

      final avgCost = InventoryCostingCalculator.calculateAverageCost(batches);
      expect(avgCost, equals(20.0));
    });
  });

  group('InventoryCostingCalculator - FIFO', () {
    test('oldest batch is first in sorted list', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now.subtract(const Duration(days: 30))),
        BatchInfo(id: 'b2', quantity: 10, costPrice: 12.0, createdAt: now.subtract(const Duration(days: 20))),
        BatchInfo(id: 'b3', quantity: 10, costPrice: 15.0, createdAt: now.subtract(const Duration(days: 10))),
      ];

      final sorted = InventoryCostingCalculator.sortFifo(batches);
      expect(sorted[0].id, equals('b1'));
      expect(sorted[1].id, equals('b2'));
      expect(sorted[2].id, equals('b3'));
    });

    test('calculates COGS using FIFO correctly', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now.subtract(const Duration(days: 30))),
        BatchInfo(id: 'b2', quantity: 10, costPrice: 12.0, createdAt: now.subtract(const Duration(days: 20))),
      ];

      final cogs = InventoryCostingCalculator.calculateCogs(
        batches,
        15.0,
        InventoryValuationMethod.fifo,
      );

      expect(cogs, closeTo(160.0, 0.01));
    });

    test('FIFO with expiry date priority', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now, expiryDate: now.add(const Duration(days: 60))),
        BatchInfo(id: 'b2', quantity: 10, costPrice: 12.0, createdAt: now, expiryDate: now.add(const Duration(days: 30))),
        BatchInfo(id: 'b3', quantity: 10, costPrice: 15.0, createdAt: now, expiryDate: now.add(const Duration(days: 90))),
      ];

      final sorted = InventoryCostingCalculator.sortByExpiryWithFifo(batches);
      expect(sorted[0].id, equals('b2'));
      expect(sorted[1].id, equals('b1'));
      expect(sorted[2].id, equals('b3'));
    });
  });

  group('InventoryCostingCalculator - LIFO', () {
    test('newest batch is first in sorted list', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now.subtract(const Duration(days: 30))),
        BatchInfo(id: 'b2', quantity: 10, costPrice: 12.0, createdAt: now.subtract(const Duration(days: 20))),
        BatchInfo(id: 'b3', quantity: 10, costPrice: 15.0, createdAt: now.subtract(const Duration(days: 10))),
      ];

      final sorted = InventoryCostingCalculator.sortLifo(batches);
      expect(sorted[0].id, equals('b3'));
      expect(sorted[1].id, equals('b2'));
      expect(sorted[2].id, equals('b1'));
    });

    test('calculates COGS using LIFO correctly', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now.subtract(const Duration(days: 30))),
        BatchInfo(id: 'b2', quantity: 10, costPrice: 12.0, createdAt: now.subtract(const Duration(days: 20))),
      ];

      final cogs = InventoryCostingCalculator.calculateCogs(
        batches,
        15.0,
        InventoryValuationMethod.lifo,
      );

      expect(cogs, closeTo(170.0, 0.01));
    });
  });

  group('InventoryCostingCalculator - Valuation Report', () {
    test('calculates total inventory value', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now),
        BatchInfo(id: 'b2', quantity: 20, costPrice: 15.0, createdAt: now),
      ];

      final valuation = InventoryCostingCalculator.getInventoryValuation(
        batches,
        InventoryValuationMethod.avco,
      );

      expect(valuation['totalQuantity'], equals(30.0));
      expect(valuation['totalValue'], equals(400.0));
    });

    test('returns zero for empty batches', () {
      final valuation = InventoryCostingCalculator.getInventoryValuation(
        [],
        InventoryValuationMethod.avco,
      );

      expect(valuation['totalQuantity'], equals(0.0));
      expect(valuation['totalValue'], equals(0.0));
    });

    test('ignores batches with zero quantity', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 0, costPrice: 10.0, createdAt: now),
        BatchInfo(id: 'b2', quantity: 25, costPrice: 20.0, createdAt: now),
      ];

      final valuation = InventoryCostingCalculator.getInventoryValuation(
        batches,
        InventoryValuationMethod.avco,
      );

      expect(valuation['totalQuantity'], equals(25.0));
    });
  });

  group('InventoryCostingCalculator - Edge Cases', () {
    test('COGS when quantity needed exceeds available', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now),
      ];

      final cogs = InventoryCostingCalculator.calculateCogs(
        batches,
        50.0,
        InventoryValuationMethod.fifo,
      );

      expect(cogs, equals(100.0));
    });

    test('COGS when exactly matches batch quantity', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 10, costPrice: 10.0, createdAt: now),
      ];

      final cogs = InventoryCostingCalculator.calculateCogs(
        batches,
        10.0,
        InventoryValuationMethod.fifo,
      );

      expect(cogs, equals(100.0));
    });

    test('handles very large quantity', () {
      final now = DateTime.now();
      final batches = [
        BatchInfo(id: 'b1', quantity: 999999, costPrice: 1.0, createdAt: now),
      ];

      final cogs = InventoryCostingCalculator.calculateCogs(
        batches,
        500000,
        InventoryValuationMethod.fifo,
      );

      expect(cogs, equals(500000.0));
    });
  });
}
