import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dart:developer' as developer;

class PackagingEngine {
  final AppDatabase db;

  PackagingEngine(this.db);

  /// جلب كافة مستويات التغليف لمنتج معين مرتبة حسب عامل التحويل
  Future<List<ProductUnit>> getPackagingHierarchy(String productId) async {
    return (db.select(db.productUnits)
          ..where((u) => u.productId.equals(productId))
          ..orderBy([(u) => OrderingTerm(expression: u.unitFactor, mode: OrderingMode.asc)]))
        .get();
  }

  /// تحويل كمية من وحدة معينة إلى الوحدة الأساسية
  Decimal convertToBase(Decimal quantity, Decimal factor) {
    return quantity * factor;
  }

  /// تحويل كمية من الوحدة الأساسية إلى وحدة معينة
  Decimal convertFromBase(Decimal quantity, Decimal factor) {
    if (factor == Decimal.zero) return Decimal.zero;
    return (quantity / factor).toDecimal();
  }

  /// تفكيك العبوات تلقائياً (Auto Break)
  Future<void> autoBreakIfNecessary({
    required String productId,
    required String warehouseId,
    required Decimal requiredQtyInBase,
  }) async {
    // المنطق الحالي يعتمد على اجمالي الكمية في الدفعات.
    // مستقبلاً يمكن إضافة تتبع للعبوات المفتوحة فعلياً.
    developer.log('Auto-break check for \$productId: \$requiredQtyInBase required');
  }

  /// تنسيق عرض المخزون بشكل هجين (مثلاً: 2 كرتون و 5 حبة)
  Future<String> formatInventoryBalance(String productId, Decimal totalQtyInBase) async {
    try {
      final hierarchy = await getPackagingHierarchy(productId);
      if (hierarchy.isEmpty) return '\${totalQtyInBase.toStringAsFixed(0)} حبة';

      final sortedHierarchy = hierarchy.reversed.toList();
      
      List<String> parts = [];
      Decimal remaining = totalQtyInBase;

      for (var unit in sortedHierarchy) {
        final factor = unit.unitFactor;
        if (factor <= Decimal.one) continue;

        final count = (remaining / factor).toDecimal(scaleOnInfinitePrecision: 0);
        if (count > Decimal.zero) {
          parts.add('\${count.toStringAsFixed(0)} \${unit.unitName}');
          remaining -= count * factor;
        }
      }

      if (remaining > Decimal.zero || parts.isEmpty) {
        parts.add('${remaining.toStringAsFixed(0)} حبة');
      }


      return parts.join(' + ');
    } catch (e) {
      return '\${totalQtyInBase.toStringAsFixed(0)}';
    }
  }

  /// اقتراح التعبئة الأنسب (Smart Suggestion)
  Future<ProductUnit?> getBestPackagingSuggestion(String productId, Decimal quantityInBase) async {
    final hierarchy = await getPackagingHierarchy(productId);
    
    ProductUnit? bestMatch;
    for (var unit in hierarchy) {
      if (unit.unitFactor > Decimal.one && unit.unitFactor <= quantityInBase) {
        if (bestMatch == null || unit.unitFactor > bestMatch.unitFactor) {
          bestMatch = unit;
        }
      }
    }
    return bestMatch;
  }

  /// التحقق من إمكانية إعادة التجميع (Auto Repack System)
  Future<String?> checkRepackPossibility(String productId, Decimal quantityInBase) async {
    final hierarchy = await getPackagingHierarchy(productId);
    final largeUnits = hierarchy.where((u) => u.unitFactor > Decimal.one).toList();
    if (largeUnits.isEmpty) return null;

    for (var unit in largeUnits.reversed) {
       if (quantityInBase >= unit.unitFactor) {
          return 'يمكنك تجميع \${(quantityInBase / unit.unitFactor).toDecimal(scaleOnInfinitePrecision: 0)} \${unit.unitName}';
       }
    }
    return null;
  }
}
