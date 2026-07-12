import 'package:dartz/dartz.dart';
import '../entities/employee.dart';
import '../../core/utils/failures.dart';

abstract class EmployeeRepository {
  Future<Either<Failure, List<EmployeeEntity>>> getAllEmployees();
  Future<Either<Failure, EmployeeEntity?>> getEmployeeById(String id);
  Future<Either<Failure, String>> createEmployee(EmployeeEntity employee);
  Future<Either<Failure, void>> updateEmployee(EmployeeEntity employee);
  Future<Either<Failure, List<PayrollRunEntity>>> getPayrollRuns();
  Future<Either<Failure, String>> createPayrollRun(PayrollRunEntity run);
}
