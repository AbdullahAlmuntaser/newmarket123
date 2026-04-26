import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:uuid/uuid.dart';
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

@DriftAccessor(
  tables: [
    Suppliers,
    SupplierPayments,
    Purchases,
    PurchaseReturns,
    GLAccounts,
    GLEntries,
    GLLines,
  ],
)
class SuppliersDao extends DatabaseAccessor<AppDatabase>
    with _$SuppliersDaoMixin {
  SuppliersDao(super.db);

  Stream<List<Supplier>> watchAllSuppliers() =>
      (select(suppliers)..where((tbl) => tbl.isActive.equals(true))).watch();

  Future<Supplier?> getSupplierById(String id) {
    return (select(suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// إدراج مورد مع إنشاء حساب محاسبي له تلقائياً
  Future<String> insertSupplierWithAccount(SuppliersCompanion entry) async {
    return transaction(() async {
      // 1. البحث عن الحساب الرئيسي للموردين (مثلاً '2010')
      final parentAccount = await (select(
        gLAccounts,
      )..where((t) => t.code.equals('2010'))).getSingleOrNull();

      final accountId = const Uuid().v4();
      final supplierId = const Uuid().v4();

      // 2. إنشاء حساب في دفتر الأستاذ العام
      await into(gLAccounts).insert(
        GLAccountsCompanion.insert(
          id: Value(accountId),
          code: '2010-${supplierId.substring(0, 5)}',
          name: 'مورد: ${entry.name.value}',
          type: AccountType
              .liability, // Removed .name as AccountType.liability is already a String
          parentId: Value(parentAccount?.id),
          isHeader: const Value(false),
          balance: const Value(0.0),
        ),
      );

      // 3. إدراج المورد وربطه بالحساب
      final finalEntry = entry.copyWith(
        id: Value(supplierId),
        accountId: Value(accountId),
      );
      await into(suppliers).insert(finalEntry);

      return supplierId;
    });
  }

  Future<bool> updateSupplier(Supplier entry) {
    return update(suppliers).replace(entry);
  }

  Future<int> deleteSupplier(Supplier entry) {
    // تعطيل المورد بدلاً من حذفه
    return (update(suppliers)..where((t) => t.id.equals(entry.id))).write(
      const SuppliersCompanion(isActive: Value(false)),
    );
  }

  /// بحث متقدم عن الموردين
  Future<List<Supplier>> searchSuppliers(String query) {
    return (select(suppliers)
          ..where(
            (t) =>
                t.name.contains(query) |
                t.phone.contains(query) |
                t.taxNumber.contains(query),
          )
          ..where((t) => t.isActive.equals(true)))
        .get();
  }

  Future<List<SupplierTransaction>> getSupplierStatement(
    String supplierId,
  ) async {
    final List<SupplierTransaction> allTransactions = [];

    // 1. جلب المشتريات الآجلة
    final supplierPurchases =
        await (select(db.purchases)..where(
              (p) => p.supplierId.equals(supplierId) & p.isCredit.equals(true),
            ))
            .get();

    for (var purchase in supplierPurchases) {
      allTransactions.add(
        SupplierTransaction(
          date: purchase.date,
          description:
              'فاتورة مشتريات رقم ${purchase.invoiceNumber ?? purchase.id.substring(0, 8)}',
          debit: purchase.total, // له
          credit: 0,
          referenceId: purchase.id,
          type: 'PURCHASE',
        ),
      );
    }

    // 2. جلب المدفوعات للمورد (سند صرف)
    final payments = await (select(
      db.supplierPayments,
    )..where((p) => p.supplierId.equals(supplierId))).get();

    for (var payment in payments) {
      allTransactions.add(
        SupplierTransaction(
          date: payment.paymentDate,
          description: 'سند صرف - ${payment.note ?? ""}',
          debit: 0,
          credit: payment.amount, // عليه
          referenceId: payment.id,
          type: 'PAYMENT',
        ),
      );
    }

    // 3. جلب المرتجعات للمورد
    final returnsQuery = select(db.purchaseReturns).join([
      innerJoin(
        db.purchases,
        db.purchases.id.equalsExp(db.purchaseReturns.purchaseId),
      ),
    ])..where(db.purchases.supplierId.equals(supplierId));

    final returnRows = await returnsQuery.get();
    for (var row in returnRows) {
      final ret = row.readTable(db.purchaseReturns);
      allTransactions.add(
        SupplierTransaction(
          date: ret.createdAt,
          description: 'مرتجع مشتريات فاتورة ${ret.purchaseId.substring(0, 8)}',
          debit: 0,
          credit: ret.amountReturned, // عليه
          referenceId: ret.id,
          type: 'RETURN',
        ),
      );
    }

    // ترتيب الحركات حسب التاريخ
    allTransactions.sort((a, b) => a.date.compareTo(b.date));

    return allTransactions;
  }
}
