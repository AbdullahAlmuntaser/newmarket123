import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'products_dao.g.dart';

class ProductWithCategory {
  final Product product;
  final Category? category;

  ProductWithCategory({required this.product, this.category});
}

class TransferItemData {
  final String productId;
  final String batchId;
  final double quantity;

  TransferItemData({
    required this.productId,
    required this.batchId,
    required this.quantity,
  });
}

@DriftAccessor(tables: [
  Products,
  Categories,
  Warehouses,
  ProductBatches,
  StockTransfers,
  StockTransferItems,
])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  // Warehouse & Batch Management
  Stream<List<Warehouse>> watchWarehouses() {
    return select(warehouses).watch();
  }

  Future<int> addWarehouse(WarehousesCompanion entry) {
    return into(warehouses).insert(entry);
  }

  Future<List<ProductBatch>> getProductBatches(String productId, String warehouseId) {
    return (select(productBatches)
          ..where((b) => b.productId.equals(productId) & b.warehouseId.equals(warehouseId) & b.quantity.isBiggerThanValue(0)))
        .get();
  }

  /// تنفيذ عملية تحويل مخزني بين مستودعين
  Future<void> transferStock({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<TransferItemData> items,
    String? note,
  }) async {
    await transaction(() async {
      // 1. إنشاء رأس التحويل
      final transfer = await into(stockTransfers).insertReturning(
        StockTransfersCompanion.insert(
          fromWarehouseId: fromWarehouseId,
          toWarehouseId: toWarehouseId,
          note: Value(note),
          transferDate: Value(DateTime.now()),
        ),
      );

      final transferId = transfer.id;

      for (var item in items) {
        // 2. جلب الدفعة المصدر
        final sourceBatch = await (select(productBatches)
              ..where((b) => b.id.equals(item.batchId)))
            .getSingle();

        if (sourceBatch.quantity < item.quantity) {
          throw Exception('الكمية المطلوبة غير متوفرة في الدفعة المحددة');
        }

        // 3. خصم الكمية من الدفعة المصدر
        await (update(productBatches)..where((b) => b.id.equals(item.batchId)))
            .write(ProductBatchesCompanion(
          quantity: Value(sourceBatch.quantity - item.quantity),
        ));

        // 4. إضافة الكمية للدفعة الهدف (أو إنشاء واحدة جديدة)
        // نبحث عن دفعة بنفس رقم الدفعة وتاريخ الانتهاء في المستودع الهدف
        final targetBatch = await (select(productBatches)
              ..where((b) =>
                  b.productId.equals(item.productId) &
                  b.warehouseId.equals(toWarehouseId) &
                  b.batchNumber.equals(sourceBatch.batchNumber)))
            .getSingleOrNull();

        if (targetBatch != null) {
          await (update(productBatches)..where((b) => b.id.equals(targetBatch.id)))
              .write(ProductBatchesCompanion(
            quantity: Value(targetBatch.quantity + item.quantity),
          ));
        } else {
          await into(productBatches).insert(
            ProductBatchesCompanion.insert(
              productId: item.productId,
              warehouseId: toWarehouseId,
              batchNumber: sourceBatch.batchNumber,
              expiryDate: Value(sourceBatch.expiryDate),
              quantity: Value(item.quantity),
              initialQuantity: Value(item.quantity),
              costPrice: Value(sourceBatch.costPrice),
            ),
          );
        }

        // 5. تحديث إجمالي المخزون في جدول المنتجات (إذا كان المخزون يمثل الإجمالي)
        // ملاحظة: في أنظمة ERP المتقدمة، يتم حساب المخزون من الدفعات مباشرة
        // ولكن للتوافق مع الكود الحالي سنقوم بتحديث حقل stock
        // (لا حاجة هنا لأن الإجمالي العام للمنتج لم يتغير، فقط توزيعه بين المستودعات)

        // 6. تسجيل الصنف في تفاصيل التحويل
        await into(stockTransferItems).insert(
          StockTransferItemsCompanion.insert(
            transferId: transferId,
            productId: item.productId,
            batchId: item.batchId,
            quantity: item.quantity,
          ),
        );
      }
    });
  }

  Stream<List<ProductWithCategory>> watchProducts({
    String? searchQuery,
    String? categoryId,
  }) {
    final query = select(products).join([
      leftOuterJoin(categories, categories.id.equalsExp(products.categoryId)),
    ]);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where(
        products.name.like('%$searchQuery%') |
            products.sku.like('%$searchQuery%'),
      );
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(products.categoryId.equals(categoryId));
    }

    query.orderBy([OrderingTerm.asc(products.name)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ProductWithCategory(
          product: row.readTable(products),
          category: row.readTableOrNull(categories),
        );
      }).toList();
    });
  }

  Stream<List<Product>> watchLowStockProducts() {
    return (select(
      products,
    )..where((p) => p.stock.isSmallerOrEqual(p.alertLimit))).watch();
  }

  Stream<int> watchLowStockCount() {
    final query = select(products)
      ..where((p) => p.stock.isSmallerOrEqual(p.alertLimit));
    return query.watch().map((list) => list.length);
  }

  Future<Product?> getProductById(String id) {
    return (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<Product?> getProductBySku(String sku) {
    return (select(
      products,
    )..where((p) => p.sku.equals(sku))).getSingleOrNull();
  }

  Future<int> addProduct(ProductsCompanion entry) {
    return into(products).insert(entry);
  }

  Future<bool> updateProduct(Product entry) {
    return update(products).replace(entry);
  }

  Future<int> deleteProduct(Product entry) {
    return delete(products).delete(entry);
  }

  // Categories
  Stream<List<Category>> watchCategories() {
    return select(categories).watch();
  }

  Future<int> addCategory(CategoriesCompanion entry) {
    return into(categories).insert(entry);
  }

  Future<bool> updateCategory(Category entry) {
    return update(categories).replace(entry);
  }

  Future<int> deleteCategory(Category entry) {
    return delete(categories).delete(entry);
  }

  Stream<List<ProductBatch>> watchExpiringBatches({int daysThreshold = 30}) {
    final thresholdDate = DateTime.now().add(Duration(days: daysThreshold));
    return (select(productBatches)
          ..where((b) =>
              b.expiryDate.isSmallerOrEqualValue(thresholdDate) &
              b.quantity.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Future<List<ProductBatch>> getExpiringBatches({int daysThreshold = 30}) async {
    final thresholdDate = DateTime.now().add(Duration(days: daysThreshold));
    return (select(productBatches)
          ..where((b) =>
              b.expiryDate.isSmallerOrEqualValue(thresholdDate) &
              b.quantity.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc)
          ]))
        .get();
  }
}
