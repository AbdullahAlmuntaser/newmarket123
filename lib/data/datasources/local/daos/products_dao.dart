import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'products_dao.g.dart';

class ProductWithCategory {
  final Product product;
  final Category? category;

  ProductWithCategory({required this.product, this.category});
}

@DriftAccessor(tables: [Products, Categories])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

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
}
