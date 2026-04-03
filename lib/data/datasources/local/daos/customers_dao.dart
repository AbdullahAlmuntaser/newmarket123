import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'customers_dao.g.dart';

class CustomerTransaction {
  final DateTime date;
  final String description;
  final double debit; // عليه (مبيعات)
  final double credit; // له (مدفوعات/مرتجعات)
  final String referenceId;
  final String type; // SALE, PAYMENT, RETURN

  CustomerTransaction({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.referenceId,
    required this.type,
  });
}

@DriftAccessor(tables: [Customers, CustomerPayments, Sales, SalesReturns])
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Stream<List<Customer>> watchAllCustomers() {
    return select(customers).watch();
  }

  Stream<int> watchTotalCustomers() {
    return select(customers).watch().map((rows) => rows.length);
  }

  Future<Customer?> getCustomerById(String id) {
    return (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCustomer(CustomersCompanion entry) {
    return into(customers).insert(entry);
  }

  Future<bool> updateCustomer(Customer entry) {
    return update(customers).replace(entry);
  }

  Future<int> deleteCustomer(Customer entry) {
    return delete(customers).delete(entry);
  }

  Future<List<CustomerPayment>> getPaymentsForCustomer(String customerId) {
    return (select(
      customerPayments,
    )..where((p) => p.customerId.equals(customerId))).get();
  }

  /// جلب كشف حساب تفصيلي للعميل
  Future<List<CustomerTransaction>> getCustomerStatement(String customerId) async {
    final List<CustomerTransaction> allTransactions = [];

    // 1. جلب المبيعات الآجلة
    final customerSales = await (select(db.sales)
          ..where((s) => s.customerId.equals(customerId) & s.isCredit.equals(true)))
        .get();

    for (var sale in customerSales) {
      allTransactions.add(CustomerTransaction(
        date: sale.createdAt,
        description: 'فاتورة مبيعات آجل رقم ${sale.id.substring(0, 8)}',
        debit: sale.total,
        credit: 0,
        referenceId: sale.id,
        type: 'SALE',
      ));
    }

    // 2. جلب المدفوعات
    final payments = await (select(db.customerPayments)
          ..where((p) => p.customerId.equals(customerId)))
        .get();

    for (var payment in payments) {
      allTransactions.add(CustomerTransaction(
        date: payment.paymentDate,
        description: 'سند قبض - ${payment.note ?? ""}',
        debit: 0,
        credit: payment.amount,
        referenceId: payment.id,
        type: 'PAYMENT',
      ));
    }

    // 3. جلب المرتجعات (إذا كانت مرتبطة ببيع آجل)
    // ملاحظة: هذا يتطلب ربط المرتجعات بالعميل عبر الفاتورة الأصلية
    final returnsQuery = select(db.salesReturns).join([
      innerJoin(db.sales, db.sales.id.equalsExp(db.salesReturns.saleId)),
    ])
      ..where(db.sales.customerId.equals(customerId));

    final returnRows = await returnsQuery.get();
    for (var row in returnRows) {
      final ret = row.readTable(db.salesReturns);
      allTransactions.add(CustomerTransaction(
        date: ret.createdAt,
        description: 'مرتجع مبيعات فاتورة ${ret.saleId.substring(0, 8)}',
        debit: 0,
        credit: ret.amountReturned,
        referenceId: ret.id,
        type: 'RETURN',
      ));
    }

    // ترتيب الحركات حسب التاريخ
    allTransactions.sort((a, b) => a.date.compareTo(b.date));
    
    return allTransactions;
  }
}
