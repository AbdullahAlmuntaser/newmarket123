// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suppliers_dao.dart';

// ignore_for_file: type=lint
mixin _$SuppliersDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $SupplierPaymentsTable get supplierPayments =>
      attachedDatabase.supplierPayments;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $PurchaseReturnsTable get purchaseReturns => attachedDatabase.purchaseReturns;
  SuppliersDaoManager get managers => SuppliersDaoManager(this);
}

class SuppliersDaoManager {
  final _$SuppliersDaoMixin _db;
  SuppliersDaoManager(this._db);
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
}
