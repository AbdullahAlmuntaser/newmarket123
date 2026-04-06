import 'package:drift/drift.dart';
import '../app_database.dart';

part 'suppliers_dao.g.dart';

class SupplierTransaction {
  final DateTime date;
  final String description;
  final double debit; // له (مشتريات)
  final double credit; // عليه (مدفوعات/مرتجعات)
  final String referenceId;
  final String type; // PURCHASE, PAYMENT, RETURN

  SupplierTransaction({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.referenceId,
    required this.type,
  });
}

@DriftAccessor(tables: [Suppliers, SupplierPayments, Purchases, PurchaseReturns])
class SuppliersDao extends DatabaseAccessor<AppDatabase> with _$SuppliersDaoMixin {
  SuppliersDao(super.db);

  Stream<List<Supplier>> watchAllSuppliers() => select(suppliers).watch();

  Future<Supplier?> getSupplierById(String id) {
    return (select(suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertSupplier(SuppliersCompanion entry) => into(suppliers).insert(entry);
  Future<bool> updateSupplier(Supplier entry) => update(suppliers).replace(entry);
  Future<int> deleteSupplier(Supplier entry) => delete(suppliers).delete(entry);

  Future<List<SupplierTransaction>> getSupplierStatement(String supplierId) async {
    final List<SupplierTransaction> allTransactions = [];

    // 1. جلب المشتريات الآجلة
    final supplierPurchases = await (select(db.purchases)
          ..where((p) => p.supplierId.equals(supplierId) & p.isCredit.equals(true)))
        .get();

    for (var purchase in supplierPurchases) {
      allTransactions.add(SupplierTransaction(
        date: purchase.date,
        description: 'فاتورة مشتريات رقم ${purchase.invoiceNumber ?? purchase.id.substring(0, 8)}',
        debit: purchase.total, // له
        credit: 0,
        referenceId: purchase.id,
        type: 'PURCHASE',
      ));
    }

    // 2. جلب المدفوعات للمورد (سند صرف)
    final payments = await (select(db.supplierPayments)
          ..where((p) => p.supplierId.equals(supplierId)))
        .get();

    for (var payment in payments) {
      allTransactions.add(SupplierTransaction(
        date: payment.paymentDate,
        description: 'سند صرف - ${payment.note ?? ""}',
        debit: 0,
        credit: payment.amount, // عليه
        referenceId: payment.id,
        type: 'PAYMENT',
      ));
    }

    // 3. جلب المرتجعات للمورد
    final returnsQuery = select(db.purchaseReturns).join([
      innerJoin(db.purchases, db.purchases.id.equalsExp(db.purchaseReturns.purchaseId)),
    ])
      ..where(db.purchases.supplierId.equals(supplierId));

    final returnRows = await returnsQuery.get();
    for (var row in returnRows) {
      final ret = row.readTable(db.purchaseReturns);
      allTransactions.add(SupplierTransaction(
        date: ret.createdAt,
        description: 'مرتجع مشتريات فاتورة ${ret.purchaseId.substring(0, 8)}',
        debit: 0,
        credit: ret.amountReturned, // عليه
        referenceId: ret.id,
        type: 'RETURN',
      ));
    }

    // ترتيب الحركات حسب التاريخ
    allTransactions.sort((a, b) => a.date.compareTo(b.date));
    
    return allTransactions;
  }
}
