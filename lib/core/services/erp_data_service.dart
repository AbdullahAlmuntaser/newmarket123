import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:drift/drift.dart';

class ProductSmartData {
  final double currentStock;
  final double averageCost;
  final double lastPurchasePrice;
  final DateTime? lastPurchaseDate;
  final double bestPurchasePrice;
  // Sales specific
  final double retailPrice;
  final double wholesalePrice;

  ProductSmartData({
    required this.currentStock,
    required this.averageCost,
    required this.lastPurchasePrice,
    this.lastPurchaseDate,
    required this.bestPurchasePrice,
    this.retailPrice = 0,
    this.wholesalePrice = 0,
  });
}

class CustomerSmartData {
  final double currentBalance;
  final double creditLimit;
  final int totalInvoices;
  final DateTime? lastPurchaseDate;
  final double lastSalePriceForProduct;

  CustomerSmartData({
    required this.currentBalance,
    required this.creditLimit,
    required this.totalInvoices,
    this.lastPurchaseDate,
    required this.lastSalePriceForProduct,
  });
}

class SupplierSmartData {
  final double currentBalance;
  final double lastPurchasePriceForProduct;
  final DateTime? lastPurchaseDateForProduct;
  final double bestPurchasePriceForProduct;

  SupplierSmartData({
    required this.currentBalance,
    required this.lastPurchasePriceForProduct,
    this.lastPurchaseDateForProduct,
    required this.bestPurchasePriceForProduct,
  });
}

class ErpDataService {
  final AppDatabase db;
  final InventoryCostingService costingService;

  ErpDataService(this.db, this.costingService);

  Future<ProductSmartData> getProductSmartData(String productId) async {
    // Current stock and average cost from costing service
    double stock = 0;
    double avgCost = 0;
    final product = await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingleOrNull();

    try {
      final valuation = await costingService.getInventoryValuation(productId);
      stock = valuation.totalQuantity;
      avgCost = valuation.averageCost;
    } catch (_) {
      stock = product?.stock ?? 0;
      avgCost = product?.buyPrice ?? 0;
    }

    // Last purchase info from PurchasesDao
    final lastItem = await db.purchasesDao.getLastPurchaseItem(productId);
    final lastPurchase = await db.purchasesDao.getLastPurchase(productId);
    final bestPrice =
        await db.purchasesDao.getBestPurchasePrice(productId) ?? 0;

    return ProductSmartData(
      currentStock: stock,
      averageCost: avgCost,
      lastPurchasePrice: lastItem?.unitPrice ?? 0,
      lastPurchaseDate: lastPurchase?.date,
      bestPurchasePrice: bestPrice,
      retailPrice: product?.sellPrice ?? 0,
      wholesalePrice: product?.wholesalePrice ?? 0,
    );
  }

  Future<CustomerSmartData> getCustomerSmartData(
    String customerId, {
    String? productId,
  }) async {
    final customer = await (db.select(
      db.customers,
    )..where((c) => c.id.equals(customerId))).getSingleOrNull();
    final balance = customer?.balance ?? 0;
    final limit = customer?.creditLimit ?? 0;

    final sales = await (db.select(
      db.sales,
    )..where((s) => s.customerId.equals(customerId))).get();
    final lastSale = sales.isNotEmpty ? sales.last : null;

    double lastPrice = 0;
    if (productId != null) {
      final query =
          db.select(db.saleItems).join([
            innerJoin(db.sales, db.sales.id.equalsExp(db.saleItems.saleId)),
          ])..where(
            db.sales.customerId.equals(customerId) &
                db.saleItems.productId.equals(productId),
          );

      query.orderBy([OrderingTerm.desc(db.sales.createdAt)]);

      final results = await query.get();
      if (results.isNotEmpty) {
        lastPrice = results.first.readTable(db.saleItems).price;
      }
    }

    return CustomerSmartData(
      currentBalance: balance,
      creditLimit: limit,
      totalInvoices: sales.length,
      lastPurchaseDate: lastSale?.createdAt,
      lastSalePriceForProduct: lastPrice,
    );
  }

  Future<SupplierSmartData> getSupplierSmartData(
    String supplierId, {
    String? productId,
  }) async {
    // Current balance
    final supplier = await (db.select(
      db.suppliers,
    )..where((s) => s.id.equals(supplierId))).getSingleOrNull();
    final balance = supplier?.balance ?? 0;

    double lastPrice = 0;
    DateTime? lastDate;
    double bestPrice = 0;

    if (productId != null) {
      final lastItem = await db.purchasesDao.getLastPurchaseItem(
        productId,
        supplierId: supplierId,
      );
      final lastPurchase = await db.purchasesDao.getLastPurchase(
        productId,
        supplierId: supplierId,
      );
      lastPrice = lastItem?.unitPrice ?? 0;
      lastDate = lastPurchase?.date;

      // Best price from this supplier
      final query =
          db.selectOnly(db.purchaseItems).join([
              innerJoin(
                db.purchases,
                db.purchases.id.equalsExp(db.purchaseItems.purchaseId),
              ),
            ])
            ..addColumns([db.purchaseItems.unitPrice.min()])
            ..where(
              db.purchaseItems.productId.equals(productId) &
                  db.purchases.supplierId.equals(supplierId),
            );

      final row = await query.getSingle();
      bestPrice = row.read(db.purchaseItems.unitPrice.min()) ?? 0;
    }

    return SupplierSmartData(
      currentBalance: balance,
      lastPurchasePriceForProduct: lastPrice,
      lastPurchaseDateForProduct: lastDate,
      bestPurchasePriceForProduct: bestPrice,
    );
  }
}
