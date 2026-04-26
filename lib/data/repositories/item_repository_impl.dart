import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/domain/entities/item.dart' as entity;
import 'package:supermarket/domain/repositories/item_repository.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';

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
          buyPrice: Value(item.defaultUnit?.buyPrice ?? 0.0),
          sellPrice: Value(item.defaultUnit?.sellPrice ?? 0.0),
          wholesalePrice: Value(item.defaultUnit?.wholesalePrice ?? 0.0),
          alertLimit: Value(item.alertLimit),
          isActive: Value(item.isActive),
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
            alertLimit: product.alertLimit,
            taxRate: product.taxRate,
            createdAt: product.createdAt,
            updatedAt: product.updatedAt,
          ),
        );
      } else {
        return Left(DatabaseFailure('Item not found'));
      }
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<entity.Item>>> getAllItems() async {
    try {
      final allProducts = await _productsDao.watchProducts().first;
      return Right(
        allProducts
            .map(
              (p) => entity.Item(
                id: p.product.id,
                name: p.product.name,
                sku: p.product.sku,
                primaryBarcode: p.product.barcode,
                categoryId: p.product.categoryId,
                isActive: p.product.isActive,
                alertLimit: p.product.alertLimit,
                taxRate: p.product.taxRate,
                createdAt: p.product.createdAt,
                updatedAt: p.product.updatedAt,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
