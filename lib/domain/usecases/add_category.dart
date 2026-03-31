import 'package:dartz/dartz.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/core/utils/usecase.dart';
import 'package:supermarket/domain/entities/category.dart';
import 'package:supermarket/domain/repositories/category_repository.dart';

class AddCategory implements UseCase<Unit, Category> {
  final CategoryRepository repository;

  AddCategory(this.repository);

  @override
  Future<Either<Failure, Unit>> call(Category params) async {
    return await repository.addCategory(params);
  }
}
