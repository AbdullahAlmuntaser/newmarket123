import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/domain/entities/category.dart' as domain_category;
import 'package:supermarket/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase appDatabase;

  CategoryRepositoryImpl({required this.appDatabase});

  @override
  Future<Either<Failure, Unit>> addCategory(
      domain_category.Category category) async {
    try {
      await appDatabase.into(appDatabase.categories).insert(
            CategoriesCompanion.insert(
              name: category.name,
              code: Value(category.code),
            ),
          );
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteCategory(String id) async {
    try {
      await (appDatabase.delete(appDatabase.categories)
            ..where((tbl) => tbl.id.equals(id)))
          .go();
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<domain_category.Category>>> getCategories() async {
    try {
      final categories = await appDatabase.select(appDatabase.categories).get();
      final domainCategories = categories
          .map(
            (c) => domain_category.Category(
              id: c.id,
              name: c.name,
              code: c.code,
            ),
          )
          .toList();
      return Right(domainCategories);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> updateCategory(
      domain_category.Category category) async {
    try {
      await (appDatabase.update(appDatabase.categories)
            ..where((tbl) => tbl.id.equals(category.id)))
          .write(
        CategoriesCompanion(
          name: Value(category.name),
          code: Value(category.code),
        ),
      );
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure());
    }
  }
}
