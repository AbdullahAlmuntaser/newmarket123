import 'package:dartz/dartz.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/core/utils/usecase.dart';
import 'package:supermarket/domain/repositories/category_repository.dart';

class DeleteCategory implements UseCase<Unit, String> {
  final CategoryRepository repository;

  DeleteCategory(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String params) async {
    return await repository.deleteCategory(params);
  }
}
