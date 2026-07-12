import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/constants/app_enums.dart';

class AgingItem {
  final String id;
  final String documentNumber;
  final DateTime date;
  final DateTime dueDate;
  final Decimal amount;
  final Decimal paid;
  final Decimal balance;
  final String? partyName;
  final String? partyId;

  AgingItem({
    required this.id,
    required this.documentNumber,
    required this.date,
    required this.dueDate,
    required this.amount,
    required this.paid,
    required this.balance,
    this.partyName,
    this.partyId,
  });

  int get daysOverdue => DateTime.now().difference(dueDate).inDays;
}

class AgingBucket {
  final String label;
  final int minDays;
  final int maxDays;
  final List<AgingItem> items;

  AgingBucket(this.label, this.minDays, this.maxDays, this.items);

  Decimal get total => items.fold(Decimal.zero, (s, i) => s + i.balance);
  int get count => items.length;
}

class AgingReport {
  final List<AgingBucket> buckets;
  final DateTime asOfDate;
  final Decimal grandTotal;

  AgingReport({
    required this.buckets,
    required this.asOfDate,
    required this.grandTotal,
  });
}

class AgingService {
  final AppDatabase db;

  AgingService(this.db);

  Future<AgingReport> getCustomerAging({
    String? customerId,
    DateTime? asOfDate,
  }) async {
    final date = asOfDate ?? DateTime.now();
    final buckets = _createBuckets();
    Decimal grandTotal = Decimal.zero;

    final query = db.select(db.sales)
      ..where((s) => s.isCredit.equals(true))
      ..where((s) => s.status.equals(DocumentStatus.posted.index));
    if (customerId != null) query.where((s) => s.customerId.equals(customerId));
    final sales = await query.get();

    for (final sale in sales) {
      final customerId = sale.customerId;
      if (customerId == null) continue;
      final payments = await (db.select(db.customerPayments)
            ..where((p) => p.customerId.equals(customerId)))
          .get();
      final totalPaid = payments.fold(Decimal.zero, (s, p) => s + p.amount);
      final balance = sale.total - totalPaid;
      if (balance <= Decimal.zero) continue;

      final customer = await (db.select(db.customers)
            ..where((c) => c.id.equals(customerId)))
          .getSingleOrNull();

      final dueDate = sale.createdAt.add(const Duration(days: 30));
      final daysOverdue = date.difference(dueDate).inDays;

      final item = AgingItem(
        id: sale.id,
        documentNumber: sale.id.substring(0, 8),
        date: sale.createdAt,
        dueDate: dueDate,
        amount: sale.total,
        paid: totalPaid,
        balance: balance,
        partyName: customer?.name,
        partyId: customer?.id,
      );

      _assignToBucket(buckets, item, daysOverdue);
      grandTotal += balance;
    }

    return AgingReport(
        buckets: buckets, asOfDate: date, grandTotal: grandTotal);
  }

  Future<AgingReport> getSupplierAging({
    String? supplierId,
    DateTime? asOfDate,
  }) async {
    final date = asOfDate ?? DateTime.now();
    final buckets = _createBuckets();
    Decimal grandTotal = Decimal.zero;

    final query = db.select(db.purchases)
      ..where((p) => p.isCredit.equals(true));
    if (supplierId != null) query.where((p) => p.supplierId.equals(supplierId));
    final purchases = await query.get();

    for (final purchase in purchases) {
      final supplierId = purchase.supplierId;
      if (supplierId == null) continue;
      final payments = await (db.select(db.supplierPayments)
            ..where((p) => p.supplierId.equals(supplierId)))
          .get();
      final totalPaid = payments.fold(Decimal.zero, (s, p) => s + p.amount);
      final balance = purchase.total - totalPaid;
      if (balance <= Decimal.zero) continue;

      final supplier = await (db.select(db.suppliers)
            ..where((s) => s.id.equals(supplierId)))
          .getSingleOrNull();

      final dueDate = purchase.date.add(const Duration(days: 30));
      final daysOverdue = date.difference(dueDate).inDays;

      final item = AgingItem(
        id: purchase.id,
        documentNumber: purchase.id.substring(0, 8),
        date: purchase.date,
        dueDate: dueDate,
        amount: purchase.total,
        paid: totalPaid,
        balance: balance,
        partyName: supplier?.name,
        partyId: supplier?.id,
      );

      _assignToBucket(buckets, item, daysOverdue);
      grandTotal += balance;
    }

    return AgingReport(
        buckets: buckets, asOfDate: date, grandTotal: grandTotal);
  }

  List<AgingBucket> _createBuckets() => [
        AgingBucket('Current', -9999, 0, []),
        AgingBucket('1-30 Days', 1, 30, []),
        AgingBucket('31-60 Days', 31, 60, []),
        AgingBucket('61-90 Days', 61, 90, []),
        AgingBucket('90+ Days', 91, 9999, []),
      ];

  void _assignToBucket(List<AgingBucket> buckets, AgingItem item, int days) {
    for (final bucket in buckets) {
      if (days >= bucket.minDays && days <= bucket.maxDays) {
        bucket.items.add(item);
        return;
      }
    }
    buckets.last.items.add(item);
  }
}
