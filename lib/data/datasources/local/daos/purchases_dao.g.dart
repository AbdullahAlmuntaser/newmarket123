// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases_dao.dart';

// ignore_for_file: type=lint
mixin _$PurchasesDaoMixin on DatabaseAccessor<AppDatabase> {
  $GLAccountsTable get gLAccounts => attachedDatabase.gLAccounts;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $ProductBatchesTable get productBatches => attachedDatabase.productBatches;
  $PurchaseItemsTable get purchaseItems => attachedDatabase.purchaseItems;
  $PurchaseOrdersTable get purchaseOrders => attachedDatabase.purchaseOrders;
  $PurchaseOrderItemsTable get purchaseOrderItems =>
      attachedDatabase.purchaseOrderItems;
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  $AuditLogsTable get auditLogs => attachedDatabase.auditLogs;
  $PurchaseReturnsTable get purchaseReturns => attachedDatabase.purchaseReturns;
  $PurchaseReturnItemsTable get purchaseReturnItems =>
      attachedDatabase.purchaseReturnItems;
  PurchasesDaoManager get managers => PurchasesDaoManager(this);
}

class PurchasesDaoManager {
  final _$PurchasesDaoMixin _db;
  PurchasesDaoManager(this._db);
  $$GLAccountsTableTableManager get gLAccounts =>
      $$GLAccountsTableTableManager(_db.attachedDatabase, _db.gLAccounts);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$ProductBatchesTableTableManager get productBatches =>
      $$ProductBatchesTableTableManager(
        _db.attachedDatabase,
        _db.productBatches,
      );
  $$PurchaseItemsTableTableManager get purchaseItems =>
      $$PurchaseItemsTableTableManager(_db.attachedDatabase, _db.purchaseItems);
  $$PurchaseOrdersTableTableManager get purchaseOrders =>
      $$PurchaseOrdersTableTableManager(
        _db.attachedDatabase,
        _db.purchaseOrders,
      );
  $$PurchaseOrderItemsTableTableManager get purchaseOrderItems =>
      $$PurchaseOrderItemsTableTableManager(
        _db.attachedDatabase,
        _db.purchaseOrderItems,
      );
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db.attachedDatabase, _db.auditLogs);
  $$PurchaseReturnsTableTableManager get purchaseReturns =>
      $$PurchaseReturnsTableTableManager(
        _db.attachedDatabase,
        _db.purchaseReturns,
      );
  $$PurchaseReturnItemsTableTableManager get purchaseReturnItems =>
      $$PurchaseReturnItemsTableTableManager(
        _db.attachedDatabase,
        _db.purchaseReturnItems,
      );
}
