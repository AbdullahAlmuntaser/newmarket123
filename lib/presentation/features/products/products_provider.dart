import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';

class ProductsProvider with ChangeNotifier {
  final AppDatabase db;
  late final AuditService _auditService;

  ProductsProvider(this.db) {
    _auditService = AuditService(db);
  }

  Future<void> addProduct(ProductsCompanion product) async {
    final id = await db.productsDao.addProduct(product);
    await _auditService.logCreate(
      'Product',
      id.toString(),
      details:
          'Product added: ${product.name.value}, SKU: ${product.sku.value}',
    );
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    await db.productsDao.updateProduct(product);
    await _auditService.logUpdate(
      'Product',
      product.id,
      details: 'Product updated: ${product.name}, SKU: ${product.sku}',
    );
    notifyListeners();
  }

  Future<void> deleteProduct(Product product) async {
    await db.productsDao.deleteProduct(product);
    await _auditService.logDelete(
      'Product',
      product.id,
      details: 'Product deleted: ${product.name}, SKU: ${product.sku}',
    );
    notifyListeners();
  }

  // Categories
  Future<void> addCategory(CategoriesCompanion category) async {
    final id = await db.productsDao.addCategory(category);
    await _auditService.logCreate(
      'Category',
      id.toString(),
      details: 'Category added: ${category.name.value}',
    );
    notifyListeners();
  }

  Future<void> updateCategory(Category category) async {
    await db.productsDao.updateCategory(category);
    await _auditService.logUpdate(
      'Category',
      category.id,
      details: 'Category updated: ${category.name}',
    );
    notifyListeners();
  }

  Future<void> deleteCategory(Category category) async {
    await db.productsDao.deleteCategory(category);
    await _auditService.logDelete(
      'Category',
      category.id,
      details: 'Category deleted: ${category.name}',
    );
    notifyListeners();
  }
}
