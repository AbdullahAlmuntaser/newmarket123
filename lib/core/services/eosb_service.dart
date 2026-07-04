import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for calculating End-of-Service Benefits (مكافآت نهاية الخدمة).
/// Based on Saudi Labor Law:
/// - First 5 years: 1/2 month salary per year
/// - After 5 years: 1 month salary per year
class EndOfServiceBenefitService {
  final AppDatabase db;

  EndOfServiceBenefitService(this.db);

  /// Calculate EOSB for an employee
  Future<EndOfServiceBenefit> calculateEOSB({
    required String employeeId,
    required DateTime endDate,
    String calculationMethod = 'STANDARD',
  }) async {
    // Get employee details
    final employee = await (db.select(db.employees)
          ..where((e) => e.id.equals(employeeId)))
        .getSingleOrNull();

    if (employee == null) throw Exception('الموظف غير موجود');

    final hireDate = employee.hireDate ?? DateTime.now();
    final lastSalary = employee.basicSalary;

    // Calculate years of service
    final totalDays = endDate.difference(hireDate).inDays;
    final totalYears = totalDays ~/ 365;
    final remainingMonths = ((totalDays % 365) / 30).floor();

    // Calculate EOSB amount based on Saudi Labor Law
    Decimal eosbAmount = Decimal.zero;

    if (totalYears <= 5) {
      // First 5 years: 1/2 month salary per year
      eosbAmount = Decimal.parse((lastSalary.toDouble() * totalYears / 2).toStringAsFixed(2));
    } else {
      // First 5 years: 1/2 month salary per year
      final firstFiveYears = Decimal.parse((lastSalary.toDouble() * 5 / 2).toStringAsFixed(2));
      // After 5 years: 1 month salary per year
      final afterFiveYears = lastSalary * Decimal.fromInt(totalYears - 5);
      eosbAmount = firstFiveYears + afterFiveYears;
    }

    // Add partial year (if applicable)
    if (remainingMonths > 0) {
      final partialYearAmount = Decimal.parse((lastSalary.toDouble() * remainingMonths / 12).toStringAsFixed(2));
      if (totalYears < 5) {
        eosbAmount += Decimal.parse((partialYearAmount.toDouble() / 2).toStringAsFixed(2));
      } else {
        eosbAmount += partialYearAmount;
      }
    }

    // Enhanced method: Include allowances
    if (calculationMethod == 'ENHANCED') {
      // Add housing allowance (25% of basic)
      final housingAllowance = Decimal.parse((lastSalary.toDouble() * 25 / 100).toStringAsFixed(2));
      eosbAmount += Decimal.parse((housingAllowance.toDouble() * totalYears / 2).toStringAsFixed(2));
    }

    final id = const Uuid().v4();
    await db.into(db.endOfServiceBenefits).insert(
          EndOfServiceBenefitsCompanion.insert(
            id: Value(id),
            employeeId: employeeId,
            hireDate: hireDate,
            endDate: endDate,
            lastSalary: lastSalary,
            totalYearsOfService: totalYears,
            eosbAmount: eosbAmount,
            calculationMethod: Value(calculationMethod),
          ),
        );

    return await (db.select(db.endOfServiceBenefits)
          ..where((e) => e.id.equals(id)))
        .getSingle();
  }

  /// Get EOSB for an employee
  Future<List<EndOfServiceBenefit>> getEmployeeEOSB(String employeeId) async {
    return await (db.select(db.endOfServiceBenefits)
          ..where((e) => e.employeeId.equals(employeeId))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  /// Get all EOSB calculations
  Future<List<EndOfServiceBenefit>> getAllEOSB({
    String? status,
  }) async {
    final query = db.select(db.endOfServiceBenefits);

    if (status != null) {
      query.where((e) => e.status.equals(status));
    }

    query.orderBy([(e) => OrderingTerm.desc(e.createdAt)]);
    return await query.get();
  }

  /// Mark EOSB as paid
  Future<void> markAsPaid(String eosbId) async {
    await (db.update(db.endOfServiceBenefits)
          ..where((e) => e.id.equals(eosbId)))
        .write(EndOfServiceBenefitsCompanion(
      status: const Value('PAID'),
      paidAt: Value(DateTime.now()),
    ));
  }

  /// Get EOSB summary
  Future<EOSBSummary> getEOSBSummary() async {
    final allEOSB = await getAllEOSB();

    Decimal totalEOSB = Decimal.zero;
    Decimal paidEOSB = Decimal.zero;
    Decimal pendingEOSB = Decimal.zero;
    int totalEmployees = 0;

    for (final eosb in allEOSB) {
      totalEOSB += eosb.eosbAmount;
      totalEmployees++;
      if (eosb.status == 'PAID') {
        paidEOSB += eosb.eosbAmount;
      } else {
        pendingEOSB += eosb.eosbAmount;
      }
    }

    return EOSBSummary(
      totalEOSB: totalEOSB,
      paidEOSB: paidEOSB,
      pendingEOSB: pendingEOSB,
      employeeCount: totalEmployees,
    );
  }
}

/// EOSB summary data class
class EOSBSummary {
  final Decimal totalEOSB;
  final Decimal paidEOSB;
  final Decimal pendingEOSB;
  final int employeeCount;

  const EOSBSummary({
    required this.totalEOSB,
    required this.paidEOSB,
    required this.pendingEOSB,
    required this.employeeCount,
  });
}
