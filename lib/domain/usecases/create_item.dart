import 'package:dartz/dartz.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';
import '../../core/utils/usecase.dart';
import '../../core/utils/failures.dart';

class CreateItemUseCase implements UseCase<void, Item> {
  final ItemRepository repository;
  CreateItemUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Item item) async {
    return await repository.createItem(item);
  }
}
