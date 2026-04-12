// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customers_dao.dart';

// ignore_for_file: type=lint
mixin _$CustomersDaoMixin on DatabaseAccessor<AppDatabase> {
  $GLAccountsTable get gLAccounts => attachedDatabase.gLAccounts;
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $CustomersTable get customers => attachedDatabase.customers;
  $CustomerPaymentsTable get customerPayments =>
      attachedDatabase.customerPayments;
  $SalesTable get sales => attachedDatabase.sales;
  $SalesReturnsTable get salesReturns => attachedDatabase.salesReturns;
  $GLEntriesTable get gLEntries => attachedDatabase.gLEntries;
  $CostCentersTable get costCenters => attachedDatabase.costCenters;
  $GLLinesTable get gLLines => attachedDatabase.gLLines;
  CustomersDaoManager get managers => CustomersDaoManager(this);
}

class CustomersDaoManager {
  final _$CustomersDaoMixin _db;
  CustomersDaoManager(this._db);
  $$GLAccountsTableTableManager get gLAccounts =>
      $$GLAccountsTableTableManager(_db.attachedDatabase, _db.gLAccounts);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db.attachedDatabase, _db.currencies);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$CustomerPaymentsTableTableManager get customerPayments =>
      $$CustomerPaymentsTableTableManager(
        _db.attachedDatabase,
        _db.customerPayments,
      );
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$SalesReturnsTableTableManager get salesReturns =>
      $$SalesReturnsTableTableManager(_db.attachedDatabase, _db.salesReturns);
  $$GLEntriesTableTableManager get gLEntries =>
      $$GLEntriesTableTableManager(_db.attachedDatabase, _db.gLEntries);
  $$CostCentersTableTableManager get costCenters =>
      $$CostCentersTableTableManager(_db.attachedDatabase, _db.costCenters);
  $$GLLinesTableTableManager get gLLines =>
      $$GLLinesTableTableManager(_db.attachedDatabase, _db.gLLines);
}
