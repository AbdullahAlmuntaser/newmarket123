import 'package:drift/drift.dart';
import 'package:supermarket/core/constants/account_codes.dart';
import 'package:supermarket/core/models/accounting/vat_report_data.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class VatService {
  final AppDatabase db;

  VatService(this.db);

  Future<VatReportData> getVatReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dao = db.accountingDao;
    final reportStartDate = startDate ?? DateTime(2000);
    final reportEndDate = endDate ?? DateTime.now();
    final outputVatAccount = await dao.getAccountByCode(AccountCodes.outputVAT);
    final inputVatAccount = await dao.getAccountByCode(AccountCodes.inputVAT);

    if (outputVatAccount == null || inputVatAccount == null) {
      throw Exception('Output VAT or Input VAT accounts not found.');
    }

    final outputVatLines = await (db.select(db.gLLines).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
      ..where(
        db.gLLines.accountId.equals(outputVatAccount.id) &
            db.gLEntries.date.isBetweenValues(
              reportStartDate,
              reportEndDate,
            ),
      ))
        .get();

    Decimal totalOutputVat = Decimal.zero;
    for (final line in outputVatLines) {
      totalOutputVat +=
          ((line.read(db.gLLines.credit) as Decimal?) ?? Decimal.zero) -
              ((line.read(db.gLLines.debit) as Decimal?) ?? Decimal.zero);
    }

    final inputVatLines = await (db.select(db.gLLines).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
      ..where(
        db.gLLines.accountId.equals(inputVatAccount.id) &
            db.gLEntries.date.isBetweenValues(
              reportStartDate,
              reportEndDate,
            ),
      ))
        .get();

    Decimal totalInputVat = Decimal.zero;
    for (final line in inputVatLines) {
      totalInputVat +=
          ((line.read(db.gLLines.debit) as Decimal?) ?? Decimal.zero) -
              ((line.read(db.gLLines.credit) as Decimal?) ?? Decimal.zero);
    }

    final taxableSales = await (db.select(db.sales)
      ..where((s) =>
          s.tax.isBiggerThan(Constant(Decimal.zero.toString())) &
          s.updatedAt.isBetweenValues(reportStartDate, reportEndDate)))
        .get();
    Decimal totalTaxableSales =
        taxableSales.fold(Decimal.zero, (sum, s) => sum + (s.total - s.tax));

    final taxablePurchases = await (db.select(db.purchases)
      ..where((p) =>
          p.tax.isBiggerThan(Constant(Decimal.zero.toString())) &
          p.updatedAt.isBetweenValues(reportStartDate, reportEndDate)))
        .get();
    Decimal totalTaxablePurchases =
        taxablePurchases.fold(Decimal.zero, (sum, p) => sum + (p.total - p.tax));

    return VatReportData(
      totalTaxableSales: totalTaxableSales,
      totalOutputVat: totalOutputVat,
      totalTaxablePurchases: totalTaxablePurchases,
      totalInputVat: totalInputVat,
      netVatPayable: totalOutputVat - totalInputVat,
      startDate: reportStartDate,
      endDate: reportEndDate,
    );
  }
}
