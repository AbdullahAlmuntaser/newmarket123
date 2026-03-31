import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'customers_dao.g.dart';

@DriftAccessor(tables: [Customers, CustomerPayments])
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Stream<int> watchTotalCustomers() {
    return select(customers).watch().map((rows) => rows.length);
  }

  Future<List<CustomerPayment>> getPaymentsForCustomer(String customerId) {
    return (select(customerPayments)
          ..where((p) => p.customerId.equals(customerId)))
        .get();
  }
}
