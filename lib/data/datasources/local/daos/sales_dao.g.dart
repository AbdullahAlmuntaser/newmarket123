// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_dao.dart';

// ignore_for_file: type=lint
mixin _$SalesDaoMixin on DatabaseAccessor<AppDatabase> {
  $GLAccountsTable get gLAccounts => attachedDatabase.gLAccounts;
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $SaleItemsTable get saleItems => attachedDatabase.saleItems;
  $SalesOrdersTable get salesOrders => attachedDatabase.salesOrders;
  $SalesOrderItemsTable get salesOrderItems => attachedDatabase.salesOrderItems;
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  $AuditLogsTable get auditLogs => attachedDatabase.auditLogs;
  $SalesReturnsTable get salesReturns => attachedDatabase.salesReturns;
  $SalesReturnItemsTable get salesReturnItems =>
      attachedDatabase.salesReturnItems;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $ProductBatchesTable get productBatches => attachedDatabase.productBatches;
  SalesDaoManager get managers => SalesDaoManager(this);
}

class SalesDaoManager {
  final _$SalesDaoMixin _db;
  SalesDaoManager(this._db);
  $$GLAccountsTableTableManager get gLAccounts =>
      $$GLAccountsTableTableManager(_db.attachedDatabase, _db.gLAccounts);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db.attachedDatabase, _db.currencies);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db.attachedDatabase, _db.saleItems);
  $$SalesOrdersTableTableManager get salesOrders =>
      $$SalesOrdersTableTableManager(_db.attachedDatabase, _db.salesOrders);
  $$SalesOrderItemsTableTableManager get salesOrderItems =>
      $$SalesOrderItemsTableTableManager(
        _db.attachedDatabase,
        _db.salesOrderItems,
      );
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db.attachedDatabase, _db.auditLogs);
  $$SalesReturnsTableTableManager get salesReturns =>
      $$SalesReturnsTableTableManager(_db.attachedDatabase, _db.salesReturns);
  $$SalesReturnItemsTableTableManager get salesReturnItems =>
      $$SalesReturnItemsTableTableManager(
        _db.attachedDatabase,
        _db.salesReturnItems,
      );
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$ProductBatchesTableTableManager get productBatches =>
      $$ProductBatchesTableTableManager(
        _db.attachedDatabase,
        _db.productBatches,
      );
}
