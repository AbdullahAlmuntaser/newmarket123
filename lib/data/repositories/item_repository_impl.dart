// Fixed Repository
import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/domain/entities/item.dart' as entity;
import 'package:supermarket/domain/repositories/item_repository.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

Decimal _toDecimal(double? value) =>
    value != null ? Decimal.parse(value.toStringAsFixed(4)) : Decimal.zero;

class ItemRepositoryImpl implements ItemRepository {
  final ProductsDao _productsDao;

  ItemRepositoryImpl(this._productsDao);

  @override
  Future<Either<Failure, void>> createItem(entity.Item item) async {
    try {
      await _productsDao.addProduct(
        ProductsCompanion.insert(
          id: Value(item.id),
          name: item.name,
          sku: item.sku,
          barcode: Value(item.primaryBarcode),
          categoryId: Value(item.categoryId),
          buyPrice: Value(_toDecimal(item.defaultUnit?.buyPrice?.toDouble())),
          sellPrice: Value(_toDecimal(item.defaultUnit?.sellPrice?.toDouble())),
          wholesalePrice:
              Value(_toDecimal(item.defaultUnit?.wholesalePrice?.toDouble())),
          alertLimit: Value(Decimal.parse(item.alertLimit.toString())),
          isActive: Value(item.isActive),
          createdAt: Value(item.createdAt),
          updatedAt: Value(item.updatedAt),
        ),
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, entity.Item>> getItemByBarcode(String barcode) async {
    try {
      final product = await _productsDao.getProductByBarcode(barcode);
      if (product != null) {
        return Right(
          entity.Item(
            id: product.id,
            name: product.name,
            sku: product.sku,
            primaryBarcode: product.barcode,
            categoryId: product.categoryId,
            isActive: product.isActive,
            alertLimit: product.alertLimit.toDouble(),
            taxRate: product.taxRate.toDouble(),
            createdAt: product.createdAt,
            updatedAt: product.updatedAt,
          ),
        );
      }
      return const Left(NotFoundFailure('Item not found'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<entity.Item>>> getAllItems() async {
    try {
      final products = await _productsDao.getAllProducts();
      return Right(
        products
            .map(
              (p) => entity.Item(
                id: p.id,
                name: p.name,
                sku: p.sku,
                primaryBarcode: p.barcode,
                categoryId: p.categoryId,
                isActive: p.isActive,
                alertLimit: p.alertLimit.toDouble(),
                taxRate: p.taxRate.toDouble(),
                createdAt: p.createdAt,
                updatedAt: p.updatedAt,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<entity.Item>>> searchItems(String query) async {
    try {
      final products = await _productsDao.getAllProducts();
      final filtered = products
          .where((p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.sku.toLowerCase().contains(query.toLowerCase()) ||
              (p.barcode?.contains(query) ?? false))
          .toList();

      return Right(
        filtered
            .map(
              (p) => entity.Item(
                id: p.id,
                name: p.name,
                sku: p.sku,
                primaryBarcode: p.barcode,
                categoryId: p.categoryId,
                isActive: p.isActive,
                alertLimit: p.alertLimit.toDouble(),
                taxRate: p.taxRate.toDouble(),
                createdAt: p.createdAt,
                updatedAt: p.updatedAt,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateItem(entity.Item item) async {
    try {
      final existingProduct = await _productsDao.getProductById(item.id);
      if (existingProduct == null) {
        return const Left(NotFoundFailure('Item not found'));
      }

      final updatedProduct = existingProduct.copyWith(
        name: item.name,
        sku: item.sku,
        barcode: Value(item.primaryBarcode),
        categoryId: Value(item.categoryId),
        isActive: item.isActive,
        alertLimit: Decimal.parse(item.alertLimit.toString()),
        taxRate: Decimal.parse(item.taxRate.toString()),
        updatedAt: item.updatedAt,
      );

      await _productsDao.updateProduct(updatedProduct);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
