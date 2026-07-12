import 'package:drift/drift.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for calculating Zakat (الزكاة) for businesses in Saudi Arabia.
/// Zakat rate is 2.5% on the zakat base (total assets - total liabilities).
class ZakatService {
  final AppDatabase db;

  ZakatService(this.db);

  /// Zakat rate (2.5%)
  static final Decimal zakatRate = Decimal.parse('2.5');

  /// Calculate Zakat for a given period
  Future<ZakatCalculation> calculateZakat({
    required String period,
    String calculationType = 'ANNUAL',
  }) async {
    // Calculate total assets
    final totalAssets = await _calculateTotalAssets();

    // Calculate total liabilities
    final totalLiabilities = await _calculateTotalLiabilities();

    // Calculate zakat base
    final zakatBase = totalAssets - totalLiabilities;

    // Calculate zakat amount
    final zakatAmount = zakatBase > Decimal.zero
        ? Decimal.parse((zakatBase.toDouble() * zakatRate.toDouble() / 100).toStringAsFixed(2))
        : Decimal.zero;

    final id = const Uuid().v4();
    await db.into(db.zakatCalculations).insert(
          ZakatCalculationsCompanion.insert(
            id: Value(id),
            period: period,
            calculationType: calculationType,
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            zakatBase: zakatBase,
            zakatAmount: zakatAmount,
          ),
        );

    return await (db.select(db.zakatCalculations)
          ..where((zc) => zc.id.equals(id)))
        .getSingle();
  }

  /// Calculate total assets from GL accounts
  Future<Decimal> _calculateTotalAssets() async {
    final assetAccounts = await (db.select(db.gLAccounts)
          ..where((a) => a.accountType.equals(AccountType.asset.index)))
        .get();

    Decimal total = Decimal.zero;
    for (final account in assetAccounts) {
      total += account.balance;
    }
    return total;
  }

  /// Calculate total liabilities from GL accounts
  Future<Decimal> _calculateTotalLiabilities() async {
    final liabilityAccounts = await (db.select(db.gLAccounts)
          ..where((a) => a.accountType.equals(AccountType.liability.index)))
        .get();

    Decimal total = Decimal.zero;
    for (final account in liabilityAccounts) {
      total += account.balance;
    }
    return total;
  }

  /// Get Zakat calculation by ID
  Future<ZakatCalculation?> getZakatCalculation(String id) async {
    return await (db.select(db.zakatCalculations)
          ..where((zc) => zc.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get all Zakat calculations
  Future<List<ZakatCalculation>> getZakatCalculations({
    String? period,
    String? status,
  }) async {
    final query = db.select(db.zakatCalculations);

    if (period != null) {
      query.where((zc) => zc.period.equals(period));
    }
    if (status != null) {
      query.where((zc) => zc.status.equals(status));
    }

    query.orderBy([(zc) => OrderingTerm.desc(zc.calculationDate)]);
    return await query.get();
  }

  /// Mark Zakat as filed
  Future<void> markAsFiled(String calculationId, {String? notes}) async {
    await (db.update(db.zakatCalculations)
          ..where((zc) => zc.id.equals(calculationId)))
        .write(ZakatCalculationsCompanion(
      status: const Value('FILED'),
      notes: notes != null ? Value(notes) : const Value.absent(),
    ));
  }

  /// Mark Zakat as paid
  Future<void> markAsPaid(String calculationId) async {
    await (db.update(db.zakatCalculations)
          ..where((zc) => zc.id.equals(calculationId)))
        .write(const ZakatCalculationsCompanion(
      status: Value('PAID'),
    ));
  }

  /// Get Zakat summary for dashboard
  Future<ZakatSummary> getZakatSummary() async {
    final currentYear = DateTime.now().year.toString();
    final calculations = await getZakatCalculations(period: currentYear);

    Decimal totalZakat = Decimal.zero;
    Decimal paidZakat = Decimal.zero;
    Decimal pendingZakat = Decimal.zero;

    for (final calc in calculations) {
      totalZakat += calc.zakatAmount;
      if (calc.status == 'PAID') {
        paidZakat += calc.zakatAmount;
      } else {
        pendingZakat += calc.zakatAmount;
      }
    }

    return ZakatSummary(
      year: currentYear,
      totalZakat: totalZakat,
      paidZakat: paidZakat,
      pendingZakat: pendingZakat,
      calculationCount: calculations.length,
    );
  }
}

/// Zakat summary data class
class ZakatSummary {
  final String year;
  final Decimal totalZakat;
  final Decimal paidZakat;
  final Decimal pendingZakat;
  final int calculationCount;

  const ZakatSummary({
    required this.year,
    required this.totalZakat,
    required this.paidZakat,
    required this.pendingZakat,
    required this.calculationCount,
  });
}
