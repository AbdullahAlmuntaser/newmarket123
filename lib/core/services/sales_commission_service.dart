import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for managing sales commissions and targets.
class SalesCommissionService {
  final AppDatabase db;

  SalesCommissionService(this.db);

  // ==================== SALES TARGETS ====================

  /// Create a sales target for a salesperson
  Future<SalesTarget> createSalesTarget({
    required String salespersonId,
    required String period,
    required Decimal targetAmount,
    required Decimal commissionRate,
  }) async {
    final id = const Uuid().v4();
    await db.into(db.salesTargets).insert(
          SalesTargetsCompanion.insert(
            id: Value(id),
            salespersonId: salespersonId,
            period: period,
            targetAmount: targetAmount,
            commissionRate: Value(commissionRate),
          ),
        );

    return await (db.select(db.salesTargets)..where((st) => st.id.equals(id)))
        .getSingle();
  }

  /// Get sales target for a salesperson in a period
  Future<SalesTarget?> getSalesTarget({
    required String salespersonId,
    required String period,
  }) async {
    return await (db.select(db.salesTargets)
          ..where((st) => st.salespersonId.equals(salespersonId))
          ..where((st) => st.period.equals(period)))
        .getSingleOrNull();
  }

  /// Update actual sales amount for a target
  Future<void> updateActualSales({
    required String salespersonId,
    required String period,
    required Decimal saleAmount,
  }) async {
    final target = await getSalesTarget(
      salespersonId: salespersonId,
      period: period,
    );

    if (target != null) {
      final newActual = target.actualAmount + saleAmount;
      await (db.update(db.salesTargets)..where((st) => st.id.equals(target.id)))
          .write(SalesTargetsCompanion(
        actualAmount: Value(newActual),
        status: Value(newActual >= target.targetAmount ? 'ACHIEVED' : 'ACTIVE'),
      ));
    }
  }

  // ==================== COMMISSIONS ====================

  /// Calculate and record commission for a sale
  Future<SalesCommission?> calculateCommission({
    required String salespersonId,
    required String saleId,
    required Decimal saleAmount,
  }) async {
    final period = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final target = await getSalesTarget(
      salespersonId: salespersonId,
      period: period,
    );

    if (target == null) return null;

    final commissionAmount = Decimal.parse((saleAmount.toDouble() * target.commissionRate.toDouble() / 100).toStringAsFixed(2));

    final id = const Uuid().v4();
    await db.into(db.salesCommissions).insert(
          SalesCommissionsCompanion.insert(
            id: Value(id),
            salespersonId: salespersonId,
            saleId: saleId,
            saleAmount: saleAmount,
            commissionRate: target.commissionRate,
            commissionAmount: commissionAmount,
            period: period,
          ),
        );

    // Update target actual amount
    await updateActualSales(
      salespersonId: salespersonId,
      period: period,
      saleAmount: saleAmount,
    );

    return await (db.select(db.salesCommissions)
          ..where((sc) => sc.id.equals(id)))
        .getSingle();
  }

  /// Get commissions for a salesperson in a period
  Future<List<SalesCommission>> getCommissions({
    String? salespersonId,
    String? period,
    String? status,
  }) async {
    final query = db.select(db.salesCommissions);

    if (salespersonId != null) {
      query.where((sc) => sc.salespersonId.equals(salespersonId));
    }
    if (period != null) {
      query.where((sc) => sc.period.equals(period));
    }
    if (status != null) {
      query.where((sc) => sc.status.equals(status));
    }

    query.orderBy([(sc) => OrderingTerm.desc(sc.createdAt)]);
    return await query.get();
  }

  /// Get commission summary for a salesperson
  Future<CommissionSummary> getCommissionSummary({
    required String salespersonId,
    required String period,
  }) async {
    final commissions = await getCommissions(
      salespersonId: salespersonId,
      period: period,
    );

    Decimal totalSales = Decimal.zero;
    Decimal totalCommission = Decimal.zero;
    int saleCount = 0;

    for (final commission in commissions) {
      totalSales += commission.saleAmount;
      totalCommission += commission.commissionAmount;
      saleCount++;
    }

    final target = await getSalesTarget(
      salespersonId: salespersonId,
      period: period,
    );

    return CommissionSummary(
      salespersonId: salespersonId,
      period: period,
      totalSales: totalSales,
      totalCommission: totalCommission,
      saleCount: saleCount,
      targetAmount: target?.targetAmount ?? Decimal.zero,
      targetAchieved: target?.status == 'ACHIEVED',
    );
  }

  /// Mark commission as paid
  Future<void> markAsPaid(List<String> commissionIds) async {
    for (final id in commissionIds) {
      await (db.update(db.salesCommissions)
            ..where((sc) => sc.id.equals(id)))
          .write(SalesCommissionsCompanion(
        status: const Value('PAID'),
        paidAt: Value(DateTime.now()),
      ));
    }
  }
}

/// Commission summary data class
class CommissionSummary {
  final String salespersonId;
  final String period;
  final Decimal totalSales;
  final Decimal totalCommission;
  final int saleCount;
  final Decimal targetAmount;
  final bool targetAchieved;

  const CommissionSummary({
    required this.salespersonId,
    required this.period,
    required this.totalSales,
    required this.totalCommission,
    required this.saleCount,
    required this.targetAmount,
    required this.targetAchieved,
  });
}
