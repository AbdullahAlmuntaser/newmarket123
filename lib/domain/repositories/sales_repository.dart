import 'package:dartz/dartz.dart';
import '../entities/sales_transaction.dart';
import '../../core/utils/failures.dart';

abstract class SalesRepository {
  Future<Either<Failure, List<SalesTransaction>>> getAllSales();
  Future<Either<Failure, SalesTransaction?>> getSaleById(String id);
  Future<Either<Failure, String>> createSale(SalesTransaction sale);
}
