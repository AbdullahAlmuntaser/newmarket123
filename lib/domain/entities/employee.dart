import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum EmploymentStatus { active, terminated, suspended }

class EmployeeEntity extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? position;
  final String? department;
  final DateTime hireDate;
  final Decimal basicSalary;
  final Decimal housingAllowance;
  final Decimal transportAllowance;
  final Decimal otherAllowances;
  final Decimal totalDeductions;
  final String? bankAccountNumber;
  final String? bankName;
  final EmploymentStatus status;

  const EmployeeEntity({
    required this.id,
    required this.name,
    required this.code,
    this.position,
    this.department,
    required this.hireDate,
    required this.basicSalary,
    required this.housingAllowance,
    required this.transportAllowance,
    required this.otherAllowances,
    required this.totalDeductions,
    this.bankAccountNumber,
    this.bankName,
    this.status = EmploymentStatus.active,
  });

  Decimal get grossSalary =>
      basicSalary + housingAllowance + transportAllowance + otherAllowances;

  Decimal get netSalary => grossSalary - totalDeductions;

  @override
  List<Object?> get props => [
        id, name, code, position, department, hireDate, basicSalary,
        housingAllowance, transportAllowance, otherAllowances,
        totalDeductions, bankAccountNumber, bankName, status,
      ];
}

class PayrollRunEntity extends Equatable {
  final String id;
  final String period;
  final DateTime runDate;
  final Decimal totalSalaries;
  final Decimal totalAllowances;
  final Decimal totalDeductions;
  final Decimal netPayable;
  final String? journalEntryId;
  final String status;
  final String? notes;
  final List<PayrollDetailEntity> details;

  const PayrollRunEntity({
    required this.id,
    required this.period,
    required this.runDate,
    required this.totalSalaries,
    required this.totalAllowances,
    required this.totalDeductions,
    required this.netPayable,
    this.journalEntryId,
    this.status = 'draft',
    this.notes,
    this.details = const [],
  });

  @override
  List<Object?> get props => [
        id, period, runDate, totalSalaries, totalAllowances,
        totalDeductions, netPayable, journalEntryId, status, notes, details,
      ];
}

class PayrollDetailEntity extends Equatable {
  final String id;
  final String payrollRunId;
  final String employeeId;
  final Decimal basicSalary;
  final Decimal housingAllowance;
  final Decimal transportAllowance;
  final Decimal otherAllowances;
  final Decimal grossSalary;
  final Decimal deductions;
  final Decimal netSalary;
  final String paymentStatus;

  const PayrollDetailEntity({
    required this.id,
    required this.payrollRunId,
    required this.employeeId,
    required this.basicSalary,
    required this.housingAllowance,
    required this.transportAllowance,
    required this.otherAllowances,
    required this.grossSalary,
    required this.deductions,
    required this.netSalary,
    this.paymentStatus = 'pending',
  });

  @override
  List<Object?> get props => [
        id, payrollRunId, employeeId, basicSalary, housingAllowance,
        transportAllowance, otherAllowances, grossSalary, deductions,
        netSalary, paymentStatus,
      ];
}
