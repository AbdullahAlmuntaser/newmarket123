import 'package:dartz/dartz.dart';
import '../entities/item.dart';
import '../../core/utils/failures.dart';

abstract class ItemRepository {
  Future<Either<Failure, void>> createItem(Item item);
  Future<Either<Failure, Item>> getItemByBarcode(String barcode);
  Future<Either<Failure, List<Item>>> getAllItems();
}
