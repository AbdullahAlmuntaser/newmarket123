import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/data/datasources/local/daos/product_units_dao.dart';

/// Service for handling unit conversions across the system.
/// All quantities are stored in base units internally.
class UnitConversionService {
  final ProductsDao productsDao;
  final ProductUnitsDao productUnitsDao;

  UnitConversionService({
    required this.productsDao,
    required this.productUnitsDao,
  });

  /// Convert a quantity from source unit to base unit for a product
  Future<double> convertToBaseUnit({
    required String productId,
    required double quantity,
    required String unitName,
  }) async {
    final product = await productsDao.getProductById(productId);
    if (product == null) throw Exception('Product not found');
    if (unitName == product.unit) return quantity;

    final productUnits = await productUnitsDao.getUnitsForProduct(productId);
    final productUnit = productUnits.firstWhere(
      (pu) => pu.unitName == unitName,
      orElse: () =>
          throw Exception('Unit "$unitName" not found for product $productId'),
    );

    return quantity * productUnit.unitFactor;
  }

  /// Convert a quantity from base unit to target unit
  Future<double> convertFromBaseUnit({
    required String productId,
    required double baseQuantity,
    required String unitName,
  }) async {
    if (baseQuantity == 0) return 0.0;
    final product = await productsDao.getProductById(productId);
    if (product == null) throw Exception('Product not found');
    if (unitName == product.unit) return baseQuantity;

    final productUnits = await productUnitsDao.getUnitsForProduct(productId);
    final productUnit = productUnits.firstWhere(
      (pu) => pu.unitName == unitName,
      orElse: () =>
          throw Exception('Unit "$unitName" not found for product $productId'),
    );

    return baseQuantity / productUnit.unitFactor;
  }

  /// Get all available units for a product (including base unit)
  Future<List<ProductUnit>> getProductUnits(String productId) async {
    final product = await productsDao.getProductById(productId);
    if (product == null) throw Exception('Product not found');

    final customUnits = await productUnitsDao.getUnitsForProduct(productId);

    // Create a virtual representation of the base unit
    // Note: We return custom units only, and handle base unit separately
    return customUnits;
  }

  /// Add a new custom unit to a product
  Future<void> addProductUnit({
    required String productId,
    required String unitName,
    required double conversionFactor,
    double? buyPrice,
    double? sellPrice,
    String? barcode,
  }) async {
    final product = await productsDao.getProductById(productId);
    if (product == null) throw Exception('Product not found');
    if (unitName == product.unit) {
      throw Exception('Cannot add base unit as custom unit');
    }

    final existingUnits = await productUnitsDao.getUnitsForProduct(productId);
    final exists = existingUnits.any((pu) => pu.unitName == unitName);
    if (exists) throw Exception('Unit "$unitName" already exists');

    if (conversionFactor <= 0) {
      throw Exception('Conversion factor must be positive');
    }

    await productUnitsDao.addProductUnit(
      ProductUnitsCompanion.insert(
        productId: productId,
        unitName: unitName,
        barcode: Value(barcode),
        unitFactor: Value(conversionFactor),
        buyPrice: Value(buyPrice),
        sellPrice: Value(sellPrice),
        isDefault: const Value(false),
      ),
    );
  }
}
