// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suppliers_dao.dart';

// ignore_for_file: type=lint
mixin _$SuppliersDaoMixin on DatabaseAccessor<AppDatabase> {
  $GLAccountsTable get gLAccounts => attachedDatabase.gLAccounts;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $SupplierPaymentsTable get supplierPayments =>
      attachedDatabase.supplierPayments;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $PurchaseReturnsTable get purchaseReturns => attachedDatabase.purchaseReturns;
  $GLEntriesTable get gLEntries => attachedDatabase.gLEntries;
  $CostCentersTable get costCenters => attachedDatabase.costCenters;
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $GLLinesTable get gLLines => attachedDatabase.gLLines;
  SuppliersDaoManager get managers => SuppliersDaoManager(this);
}

class SuppliersDaoManager {
  final _$SuppliersDaoMixin _db;
  SuppliersDaoManager(this._db);
  $$GLAccountsTableTableManager get gLAccounts =>
      $$GLAccountsTableTableManager(_db.attachedDatabase, _db.gLAccounts);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$SupplierPaymentsTableTableManager get supplierPayments =>
      $$SupplierPaymentsTableTableManager(
        _db.attachedDatabase,
        _db.supplierPayments,
      );
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$PurchaseReturnsTableTableManager get purchaseReturns =>
      $$PurchaseReturnsTableTableManager(
        _db.attachedDatabase,
        _db.purchaseReturns,
      );
  $$GLEntriesTableTableManager get gLEntries =>
      $$GLEntriesTableTableManager(_db.attachedDatabase, _db.gLEntries);
  $$CostCentersTableTableManager get costCenters =>
      $$CostCentersTableTableManager(_db.attachedDatabase, _db.costCenters);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db.attachedDatabase, _db.currencies);
  $$GLLinesTableTableManager get gLLines =>
      $$GLLinesTableTableManager(_db.attachedDatabase, _db.gLLines);
}
