import 'package:dartz/dartz.dart';
import 'package:supermarket/core/utils/failures.dart';
import 'package:supermarket/core/utils/usecase.dart';
import 'package:supermarket/domain/entities/category.dart';
import 'package:supermarket/domain/repositories/category_repository.dart';

class GetCategories implements UseCase<List<Category>, NoParams> {
  final CategoryRepository repository;

  GetCategories(this.repository);

  @override
  Future<Either<Failure, List<Category>>> call(NoParams params) async {
    return await repository.getCategories();
  }
}
