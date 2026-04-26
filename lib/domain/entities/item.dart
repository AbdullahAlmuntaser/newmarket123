import 'package:equatable/equatable.dart';

/// Represents a product/item in the system with full ERP capabilities
class Item extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String sku;
  final String? primaryBarcode;
  final String? categoryId;
  final bool isActive;
  final double alertLimit;
  final double taxRate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ItemVariant> variants;
  final List<ItemUnit>
  units; // Base units when no variants, or all units when variants exist

  const Item({
    required this.id,
    required this.name,
    this.description,
    required this.sku,
    this.primaryBarcode,
    this.categoryId,
    this.isActive = true,
    this.alertLimit = 10.0,
    this.taxRate = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.variants = const [],
    this.units = const [],
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    sku,
    primaryBarcode,
    categoryId,
    isActive,
    alertLimit,
    taxRate,
    createdAt,
    updatedAt,
    variants,
    units,
  ];

  /// Get the default/base unit
  ItemUnit? get defaultUnit {
    try {
      return units.firstWhere((u) => u.isDefault);
    } catch (e) {
      return units.isNotEmpty ? units.first : null;
    }
  }

  /// Check if item has variants
  bool get hasVariants => variants.isNotEmpty;

  /// Get all available barcodes for this item (including variant and unit barcodes)
  List<String> getAllBarcodes() {
    final barcodes = <String>[];
    if (primaryBarcode != null) barcodes.add(primaryBarcode!);
    for (var variant in variants) {
      if (variant.barcode != null) barcodes.add(variant.barcode!);
      for (var unit in variant.units) {
        if (unit.barcode != null) barcodes.add(unit.barcode!);
      }
    }
    // Also include unit barcodes for items without variants
    if (variants.isEmpty) {
      for (var unit in units) {
        if (unit.barcode != null) barcodes.add(unit.barcode!);
      }
    }
    return barcodes;
  }
}

/// Represents a variant of an item (e.g., color, size, style)
class ItemVariant extends Equatable {
  final String id;
  final String itemId;
  final Map<String, String> attributes; // e.g., {'color': 'Red', 'size': 'XL'}
  final String? sku;
  final String? barcode;
  final double? additionalCost;
  final List<ItemUnit> units;

  const ItemVariant({
    required this.id,
    required this.itemId,
    this.attributes = const {},
    this.sku,
    this.barcode,
    this.additionalCost,
    this.units = const [],
  });

  @override
  List<Object?> get props => [
    id,
    itemId,
    attributes,
    sku,
    barcode,
    additionalCost,
    units,
  ];

  /// Get a human-readable name for this variant
  String getVariantName() {
    if (attributes.isEmpty) return '';
    return attributes.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
}

/// Represents a unit of measurement for an item or variant
class ItemUnit extends Equatable {
  final String id;
  final String itemId;
  final String? variantId; // null if this unit belongs to the base item
  final String unitName; // e.g., 'piece', 'carton', 'kg', 'box'
  final String? barcode;
  final double conversionFactor; // How many base units in this unit
  final bool isDefault;
  final double? buyPrice;
  final double? sellPrice;
  final double? wholesalePrice;
  final double? halfWholesalePrice; // Additional price level

  const ItemUnit({
    required this.id,
    required this.itemId,
    this.variantId,
    required this.unitName,
    this.barcode,
    this.conversionFactor = 1.0,
    this.isDefault = false,
    this.buyPrice,
    this.sellPrice,
    this.wholesalePrice,
    this.halfWholesalePrice,
  });

  @override
  List<Object?> get props => [
    id,
    itemId,
    variantId,
    unitName,
    barcode,
    conversionFactor,
    isDefault,
    buyPrice,
    sellPrice,
    wholesalePrice,
    halfWholesalePrice,
  ];
}

/// Represents a price level for an item (can be used for price lists)
class ItemPrice extends Equatable {
  final String id;
  final String itemId;
  final String? variantId;
  final String? unitId;
  final String priceType; // 'retail', 'wholesale', 'half_wholesale', 'cost'
  final double price;
  final double? minQuantity; // Minimum quantity for this price

  const ItemPrice({
    required this.id,
    required this.itemId,
    this.variantId,
    this.unitId,
    required this.priceType,
    required this.price,
    this.minQuantity,
  });

  @override
  List<Object?> get props => [
    id,
    itemId,
    variantId,
    unitId,
    priceType,
    price,
    minQuantity,
  ];
}
