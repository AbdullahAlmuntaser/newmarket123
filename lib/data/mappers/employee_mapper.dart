import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/domain/entities/employee.dart';

class EmployeeMapper {
  EmployeeEntity fromDrift(HREmployee source) {
    return EmployeeEntity(
      id: source.id,
      name: source.name,
      code: source.code,
      position: source.position,
      department: source.department,
      hireDate: source.hireDate,
      basicSalary: Decimal.parse(source.basicSalary.toString()),
      housingAllowance: Decimal.parse(source.housingAllowance.toString()),
      transportAllowance: Decimal.parse(source.transportAllowance.toString()),
      otherAllowances: Decimal.parse(source.otherAllowances.toString()),
      totalDeductions: Decimal.parse(source.totalDeductions.toString()),
      bankAccountNumber: source.bankAccountNumber,
      bankName: source.bankName,
      status: _mapStatus(source.status),
    );
  }

  EmploymentStatus _mapStatus(String status) {
    switch (status) {
      case 'active':
        return EmploymentStatus.active;
      case 'terminated':
        return EmploymentStatus.terminated;
      case 'suspended':
        return EmploymentStatus.suspended;
      default:
        return EmploymentStatus.active;
    }
  }
}
