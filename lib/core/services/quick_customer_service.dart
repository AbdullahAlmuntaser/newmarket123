import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/customers_dao.dart';

/// Service for handling Quick Customer operations
class QuickCustomerService {
  final AppDatabase db;
  final CustomersDao customersDao;

  QuickCustomerService(this.db) : customersDao = db.customersDao;

  /// Smart search for customers with Quick Customer creation logic
  Future<CustomerSearchResult?> smartSearchAndCreate(String name, {String? phone}) async {
    if (name.trim().isEmpty) return null;

    // final normalizedInput = NameNormalizer.normalize(name);

    // 1. Check for exact match first
    final exactMatch = await customersDao.findByNormalizedName(name);
    if (exactMatch != null) {
      return CustomerSearchResult(
        customer: exactMatch,
        similarity: 1.0,
        isExactMatch: true,
      );
    }

    // 2. Perform smart search for similar customers
    final searchResults = await customersDao.smartSearchCustomers(name);

    // 3. If we have good matches (similarity >= 0.8), return the best one
    if (searchResults.isNotEmpty && searchResults.first.similarity >= 0.8) {
      return searchResults.first;
    }

    // 4. If no good matches, create a Quick Customer
    final customerId = await customersDao.createQuickCustomer(name, phone: phone);
    final newCustomer = await customersDao.getCustomerById(customerId);

    return newCustomer != null
        ? CustomerSearchResult(
            customer: newCustomer,
            similarity: 1.0,
            isExactMatch: true,
          )
        : null;
  }

  /// Get or create customer for POS sale
  /// This is the main method used in POS checkout
  Future<Customer?> getOrCreateCustomerForSale(String name, {String? phone}) async {
    final result = await smartSearchAndCreate(name, phone: phone);
    return result?.customer;
  }

  /// Validate customer for sale type
  /// Returns null if valid, error message if invalid
  String? validateCustomerForSale(Customer? customer, bool isCreditSale) {
    if (customer == null) {
      return 'يجب اختيار عميل للبيع الآجل';
    }

    if (isCreditSale && customer.isQuickCustomer) {
      return 'لا يمكن البيع الآجل للعملاء السريعين. يرجى اختيار عميل رسمي أو إنشاء عميل جديد.';
    }

    return null; // Valid
  }

  /// Get all Quick Customers for management
  Future<List<Customer>> getQuickCustomers() {
    return customersDao.getQuickCustomers();
  }

  /// Upgrade Quick Customer to regular customer
  Future<bool> upgradeQuickCustomer(String customerId, {
    required String customerType,
    double creditLimit = 0.0,
    String? phone,
    String? address,
    String? email,
  }) async {
    try {
      await (db.update(db.customers)
        ..where((c) => c.id.equals(customerId)))
        .write(CustomersCompanion(
          isQuickCustomer: const Value(false),
          customerType: Value(customerType),
          creditLimit: Value(creditLimit),
          phone: Value(phone),
          address: Value(address),
          email: Value(email),
          updatedAt: Value(DateTime.now()),
        ));

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Merge duplicate customers
  Future<bool> mergeCustomers(String primaryCustomerId, List<String> duplicateIds) async {
    try {
      await db.transaction(() async {
        // Transfer sales to primary customer
        for (final duplicateId in duplicateIds) {
          await (db.update(db.sales)
            ..where((s) => s.customerId.equals(duplicateId)))
            .write(SalesCompanion(
              customerId: Value(primaryCustomerId),
              updatedAt: Value(DateTime.now()),
            ));
        }

        // Mark duplicates as inactive
        for (final duplicateId in duplicateIds) {
          await (db.update(db.customers)
            ..where((c) => c.id.equals(duplicateId)))
            .write(CustomersCompanion(
              isActive: const Value(false),
              updatedAt: Value(DateTime.now()),
            ));
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clean up old Quick Customers (optional maintenance)
  Future<int> cleanupOldQuickCustomers({Duration olderThan = const Duration(days: 365)}) async {
    final cutoffDate = DateTime.now().subtract(olderThan);

    try {
      final oldQuickCustomers = await (db.select(db.customers)
        ..where((c) => c.isQuickCustomer.equals(true))
        ..where((c) => c.createdAt.isSmallerThanValue(cutoffDate))
        ..where((c) => c.balance.equals(0.0))) // Only if no outstanding balance
        .get();

      for (final customer in oldQuickCustomers) {
        await (db.update(db.customers)
          ..where((c) => c.id.equals(customer.id)))
          .write(CustomersCompanion(isActive: const Value(false)));
      }

      return oldQuickCustomers.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get customer statistics
  Future<Map<String, int>> getCustomerStats() async {
    final allCustomers = await db.select(db.customers).get();

    final stats = {
      'total': allCustomers.length,
      'active': allCustomers.where((c) => c.isActive).length,
      'quick': allCustomers.where((c) => c.isQuickCustomer).length,
      'regular': allCustomers.where((c) => !c.isQuickCustomer).length,
      'vip': allCustomers.where((c) => c.customerType == 'VIP').length,
      'wholesale': allCustomers.where((c) => c.customerType == 'WHOLESALE').length,
    };

    return stats;
  }
}