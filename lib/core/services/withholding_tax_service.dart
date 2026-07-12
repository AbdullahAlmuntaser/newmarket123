import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for managing withholding tax (ضريبة الاحتفاظ).
/// In Saudi Arabia, withholding tax applies to payments to non-residents.
class WithholdingTaxService {
  final AppDatabase db;

  WithholdingTaxService(this.db);

  /// WHT rates for Saudi Arabia
  static const Map<String, double> whtRates = {
    'DIVIDENDS': 5.0,
    'INTEREST': 5.0,
    'ROYALTIES': 15.0,
    'SERVICE_FEES': 15.0,
    'TECHNICAL_FEES': 15.0,
    'COMMISSIONS': 15.0,
    'RENT': 15.0,
    'INSURANCE': 5.0,
  };

  /// Create a withholding tax entry for a supplier payment
  Future<WithholdingTaxEntry> createWhtEntry({
    required String paymentId,
    required String paymentType,
    required String supplierId,
    required Decimal grossAmount,
    required String whtType,
  }) async {
    final rate = whtRates[whtType] ?? 15.0;
    final taxAmount = Decimal.parse((grossAmount.toDouble() * rate / 100).toStringAsFixed(2));
    final netAmount = grossAmount - taxAmount;

    final id = const Uuid().v4();
    await db.into(db.withholdingTaxEntries).insert(
          WithholdingTaxEntriesCompanion.insert(
            id: Value(id),
            paymentId: paymentId,
            paymentType: paymentType,
            supplierId: supplierId,
            grossAmount: grossAmount,
            taxRate: Decimal.parse(rate.toString()),
            taxAmount: taxAmount,
            netAmount: netAmount,
            taxDate: DateTime.now(),
          ),
        );

    return await (db.select(db.withholdingTaxEntries)
          ..where((w) => w.id.equals(id)))
        .getSingle();
  }

  /// Get all WHT entries for a period
  Future<List<WithholdingTaxEntry>> getWhtEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final query = db.select(db.withholdingTaxEntries);

    if (startDate != null) {
      query.where((w) => w.taxDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((w) => w.taxDate.isSmallerOrEqualValue(endDate));
    }
    if (status != null) {
      query.where((w) => w.status.equals(status));
    }

    query.orderBy([(w) => OrderingTerm.desc(w.taxDate)]);
    return await query.get();
  }

  /// Get WHT summary for a period
  Future<WhtSummary> getWhtSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final entries = await getWhtEntries(startDate: startDate, endDate: endDate);

    Decimal totalGross = Decimal.zero;
    Decimal totalTax = Decimal.zero;
    Decimal totalNet = Decimal.zero;

    for (final entry in entries) {
      totalGross += entry.grossAmount;
      totalTax += entry.taxAmount;
      totalNet += entry.netAmount;
    }

    return WhtSummary(
      periodStart: startDate,
      periodEnd: endDate,
      totalGrossAmount: totalGross,
      totalTaxAmount: totalTax,
      totalNetAmount: totalNet,
      entryCount: entries.length,
    );
  }

  /// Mark WHT entry as filed
  Future<void> markAsFiled(String entryId, String referenceNumber) async {
    await (db.update(db.withholdingTaxEntries)
          ..where((w) => w.id.equals(entryId)))
        .write(WithholdingTaxEntriesCompanion(
      status: const Value('FILED'),
      referenceNumber: Value(referenceNumber),
    ));
  }

  /// Mark WHT entry as paid
  Future<void> markAsPaid(String entryId) async {
    await (db.update(db.withholdingTaxEntries)
          ..where((w) => w.id.equals(entryId)))
        .write(const WithholdingTaxEntriesCompanion(
      status: Value('PAID'),
    ));
  }
}

/// WHT summary data class
class WhtSummary {
  final DateTime periodStart;
  final DateTime periodEnd;
  final Decimal totalGrossAmount;
  final Decimal totalTaxAmount;
  final Decimal totalNetAmount;
  final int entryCount;

  const WhtSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalGrossAmount,
    required this.totalTaxAmount,
    required this.totalNetAmount,
    required this.entryCount,
  });
}
