import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:supermarket/core/utils/name_normalizer.dart';
import 'package:uuid/uuid.dart';

part 'customers_dao.g.dart';

class CustomerSearchResult {
  final Customer customer;
  final double similarity; // 0.0 to 1.0
  final bool isExactMatch;

  CustomerSearchResult({
    required this.customer,
    required this.similarity,
    required this.isExactMatch,
  });
}

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

@DriftAccessor(
  tables: [
    Customers,
    CustomerPayments,
    Sales,
    SalesReturns,
    GLAccounts,
    GLEntries,
    GLLines,
  ],
)
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Stream<List<Customer>> watchAllCustomers() {
    return (select(
      customers,
    )..where((tbl) => tbl.isActive.equals(true))).watch();
  }

  Stream<int> watchTotalCustomers() {
    return select(customers).watch().map((rows) => rows.length);
  }

  Future<Customer?> getCustomerById(String id) {
    return (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// إدراج عميل مع إنشاء حساب محاسبي له تلقائياً
  Future<String> insertCustomerWithAccount(CustomersCompanion entry) async {
    return transaction(() async {
      // 1. البحث عن الحساب الرئيسي للعملاء (مثلاً '1201')
      // إذا لم يوجد، نستخدم حساب الأصول المتداولة الرئيسي
      final parentAccount = await (select(
        gLAccounts,
      )..where((t) => t.code.equals('1201'))).getSingleOrNull();

      final accountId = const Uuid().v4();
      final customerId = const Uuid().v4();

      // 2. إنشاء حساب في دفتر الأستاذ العام
      await into(gLAccounts).insert(
        GLAccountsCompanion.insert(
          id: Value(accountId),
          code: '1201-${customerId.substring(0, 5)}',
          name: 'عميل: ${entry.name.value}',
          type:
              AccountType.asset, // Corrected to use the static String constant
          parentId: parentAccount?.id != null
              ? Value(parentAccount!.id)
              : const Value.absent(),
          isHeader: Value(false),
          balance: Value(0.0),
        ),
      );

      // 3. إدراج العميل وربطه بالحساب
      final finalEntry = entry.copyWith(
        id: Value(customerId),
        accountId: Value(accountId),
      );
      await into(customers).insert(finalEntry);

      return customerId;
    });
  }

  Future<bool> updateCustomer(Customer entry) {
    return update(customers).replace(entry);
  }

  Future<int> deleteCustomer(Customer entry) {
    // نفضل التغيير إلى غير نشط بدلاً من الحذف الفعلي للحفاظ على السجلات المالية
    return (update(customers)..where((t) => t.id.equals(entry.id))).write(
      const CustomersCompanion(isActive: Value(false)),
    );
  }

  /// بحث متقدم عن العملاء
  Future<List<Customer>> searchCustomers(String query) {
    return (select(customers)
          ..where(
            (t) =>
                t.name.contains(query) |
                t.phone.contains(query) |
                t.taxNumber.contains(query),
          )
          ..where((t) => t.isActive.equals(true)))
        .get();
  }

  Future<List<CustomerPayment>> getPaymentsForCustomer(String customerId) {
    return (select(
      customerPayments,
    )..where((p) => p.customerId.equals(customerId))).get();
  }

  /// جلب كشف حساب تفصيلي للعميل مع الرصيد التراكمي
  Future<List<CustomerTransaction>> getCustomerStatement(
    String customerId,
  ) async {
    final List<CustomerTransaction> allTransactions = [];

    // 1. جلب المبيعات الآجلة
    final customerSales =
        await (select(db.sales)..where(
              (s) => s.customerId.equals(customerId) & s.isCredit.equals(true),
            ))
            .get();

    for (var sale in customerSales) {
      allTransactions.add(
        CustomerTransaction(
          date: sale.createdAt,
          description: 'فاتورة مبيعات آجل رقم ${sale.id.substring(0, 8)}',
          debit: sale.total,
          credit: 0,
          referenceId: sale.id,
          type: 'SALE',
        ),
      );
    }

    // 2. جلب المدفوعات
    final payments = await (select(
      db.customerPayments,
    )..where((p) => p.customerId.equals(customerId))).get();

    for (var payment in payments) {
      allTransactions.add(
        CustomerTransaction(
          date: payment.paymentDate,
          description: 'سند قبض - ${payment.note ?? ""}',
          debit: 0,
          credit: payment.amount,
          referenceId: payment.id,
          type: 'PAYMENT',
        ),
      );
    }

    // 3. جلب المرتجعات
    final returnsQuery = select(db.salesReturns).join([
      innerJoin(db.sales, db.sales.id.equalsExp(db.salesReturns.saleId)),
    ])..where(db.sales.customerId.equals(customerId));

    final returnRows = await returnsQuery.get();
    for (var row in returnRows) {
      final ret = row.readTable(db.salesReturns);
      allTransactions.add(
        CustomerTransaction(
          date: ret.createdAt,
          description: 'مرتجع مبيعات فاتورة ${ret.saleId.substring(0, 8)}',
          debit: 0,
          credit: ret.amountReturned,
          referenceId: ret.id,
          type: 'RETURN',
        ),
      );
    }

    // ترتيب الحركات حسب التاريخ
    allTransactions.sort((a, b) => a.date.compareTo(b.date));

    return allTransactions;
  }

  // ============================================
  // Quick Customer Smart Search Methods
  // ============================================

  /// Smart search for customers by name
  /// Returns list of search results with similarity scores
  Future<List<CustomerSearchResult>> smartSearchCustomers(String query) async {
    if (query.isEmpty) return [];

    final normalizedQuery = NameNormalizer.normalize(query);

    // Get all active customers
    final allCustomers = await (select(
      customers,
    )..where((c) => c.isActive.equals(true))).get();

    final results = <CustomerSearchResult>[];

    for (final customer in allCustomers) {
      // Use normalizedName if available, otherwise normalize on-the-fly
      final customerNormalized =
          customer.normalizedName ?? NameNormalizer.normalize(customer.name);

      // Exact match
      if (customerNormalized == normalizedQuery) {
        results.add(
          CustomerSearchResult(
            customer: customer,
            similarity: 1.0,
            isExactMatch: true,
          ),
        );
      }
      // Fuzzy match
      else {
        final similarity = NameNormalizer.calculateSimilarity(
          customerNormalized,
          normalizedQuery,
        );

        // Include if similarity >= 0.6 (60%)
        if (similarity >= 0.6) {
          results.add(
            CustomerSearchResult(
              customer: customer,
              similarity: similarity,
              isExactMatch: false,
            ),
          );
        }
      }
    }

    // Sort by similarity (highest first), then exact matches first
    results.sort((a, b) {
      if (a.isExactMatch && !b.isExactMatch) return -1;
      if (!a.isExactMatch && b.isExactMatch) return 1;
      return b.similarity.compareTo(a.similarity);
    });

    return results;
  }

  /// Find exact match by normalized name
  Future<Customer?> findByNormalizedName(String name) async {
    final normalized = NameNormalizer.normalize(name);
    return (select(customers)
          ..where((c) => c.normalizedName.equals(normalized))
          ..where((c) => c.isActive.equals(true)))
        .getSingleOrNull();
  }

  /// Create a quick customer from POS
  Future<String> createQuickCustomer(String name, {String? phone}) async {
    final normalized = NameNormalizer.normalize(name);

    return transaction(() async {
      final customerId = const Uuid().v4();

      // 1. Create customer with normalized name
      await into(customers).insert(
        CustomersCompanion.insert(
          id: Value(customerId),
          name: name,
          normalizedName: Value(normalized),
          phone: Value(phone),
          isQuickCustomer: const Value(true),
          createdFromPOS: const Value(true),
          creditLimit: const Value(0.0),
          balance: const Value(0.0),
          isActive: const Value(true),
        ),
      );

      return customerId;
    });
  }

  /// Get all quick customers (created from POS)
  Future<List<Customer>> getQuickCustomers() {
    return (select(customers)
          ..where((c) => c.isQuickCustomer.equals(true))
          ..where((c) => c.isActive.equals(true)))
        .get();
  }

  /// Watch only regular (non-quick) customers for credit sales
  Stream<List<Customer>> watchRegularCustomers() {
    return (select(customers)
          ..where((c) => c.isActive.equals(true))
          ..where((c) => c.isQuickCustomer.equals(false)))
        .watch();
  }
}
