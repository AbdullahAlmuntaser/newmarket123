import 'dart:convert';
import 'dart:io';
// ignore_for_file: deprecated_member_use
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supermarket/native_sql_override.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:decimal/decimal.dart';
import 'package:crypto/crypto.dart';

import 'package:uuid/uuid.dart';
import 'package:supermarket/core/services/security_service.dart';
import 'package:supermarket/core/constants/app_enums.dart';

import 'daos/products_dao.dart';
import 'daos/sales_dao.dart';
import 'daos/customers_dao.dart';
import 'daos/accounting_dao.dart';
import 'daos/users_dao.dart';
import 'daos/suppliers_dao.dart';
import 'daos/purchases_dao.dart';
import 'daos/bom_dao.dart';
import 'daos/warehouses_dao.dart';
import 'daos/global_units_dao.dart';
import 'daos/product_units_dao.dart';
import 'daos/audit_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/cashbox_dao.dart';
import 'daos/transfers_dao.dart';
import 'converters/decimal_converter.dart';
import 'tables/app_config_table.dart';
import 'tables/fixed_assets_tables.dart';
import 'tables/payroll_tables.dart';
import 'tables/advanced_accounting_tables.dart';

export 'package:decimal/decimal.dart';
export 'converters/decimal_converter.dart';

part 'app_database.g.dart';

// Type Converters
class DocumentStatusConverter extends TypeConverter<DocumentStatus, int> {
  const DocumentStatusConverter();
  @override
  DocumentStatus fromSql(int fromDb) => DocumentStatus.values[fromDb];
  @override
  int toSql(DocumentStatus value) => value.index;
}

class PaymentMethodConverter extends TypeConverter<PaymentMethod, int> {
  const PaymentMethodConverter();
  @override
  PaymentMethod fromSql(int fromDb) => PaymentMethod.values[fromDb];
  @override
  int toSql(PaymentMethod value) => value.index;
}

mixin SyncableTable on Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deviceId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  TextColumn get branchId => text().nullable().references(Branches, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class Branches extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get code => text().unique()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Users extends Table with SyncableTable {
  TextColumn get username => text().unique()();
  TextColumn get password => text()();
  TextColumn get role => text()();
  TextColumn get fullName => text()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get passwordSalt => text().nullable()();
}

class Categories extends Table with SyncableTable {
  TextColumn get name => text().unique()();
  TextColumn get code => text().unique().nullable()();
}

class Products extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get sku => text().unique()();
  TextColumn get barcode => text().nullable()(); // Primary barcode
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get unit =>
      text().withDefault(const Constant('pcs'))(); // Base unit
  TextColumn get cartonUnit => text().withDefault(const Constant('carton'))();
  IntColumn get piecesPerCarton => integer().withDefault(const Constant(1))();
  TextColumn get kiloUnit => text().nullable()();
  TextColumn get boxUnit => text().nullable()();
  TextColumn get buyPrice => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get sellPrice => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get wholesalePrice => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get stock => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get maxStock => text().map(const DecimalConverter()).withDefault(Constant(Decimal.fromInt(1000).toString()))();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get valuationMethod =>
      text().withDefault(const Constant('FIFO'))(); // FIFO, AVCO
  BoolColumn get allowFreeQty => boolean().withDefault(const Constant(false))();
  BoolColumn get isService => boolean().withDefault(const Constant(false))();
  TextColumn get alertLimit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.fromInt(10).toString()))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get taxRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // Variant support
  TextColumn get parentProductId => text().nullable().references(
        Products,
        #id,
      )(); // Null for main items; points to parent for variants
  TextColumn get attributes =>
      text().nullable()(); // JSON: {"color":"Red","size":"XL"}
  TextColumn get additionalCost =>
      text().map(const DecimalConverter()).nullable()(); // Extra cost for variant over base product
}

class ProductUnits extends Table with SyncableTable {
  // Multi-unit support for products (and variants)
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitName => text()(); // e.g., carton, box, kilo
  TextColumn get barcode =>
      text().unique().nullable()(); // Barcode for this unit
  TextColumn get unitFactor =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))(); // How many base units
  TextColumn get buyPrice => text().map(const DecimalConverter()).nullable()(); // Unit-specific buy price
  TextColumn get sellPrice => text().map(const DecimalConverter()).nullable()(); // Unit-specific sell price
  TextColumn get wholesalePrice =>
      text().map(const DecimalConverter()).nullable()(); // Wholesale price for this unit
  TextColumn get halfWholesalePrice =>
      text().map(const DecimalConverter()).nullable()(); // Half-wholesale price
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Customers extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get normalizedName => text().nullable()(); // For smart search
  TextColumn get phone => text().nullable()();
  TextColumn get taxNumber => text().nullable()(); // New: Tax Number for ERP
  TextColumn get address => text().nullable()(); // New: Detailed Address
  TextColumn get email => text().nullable()(); // New: Email
  TextColumn get customerType => text().withDefault(
        const Constant('RETAIL'),
      )(); // New: RETAIL, WHOLESALE, VIP
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))(); // New: Status
  TextColumn get creditLimit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get balance => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get accountId =>
      text().nullable().references(GLAccounts, #id)(); // New: Linked to GL
  TextColumn get currencyId => text().nullable().references(Currencies, #id)();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
  BoolColumn get isQuickCustomer =>
      boolean().withDefault(const Constant(false))(); // Quick customer flag
  BoolColumn get createdFromPOS =>
      boolean().withDefault(const Constant(false))(); // Created from POS
  TextColumn get discountRate =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // Customer-specific discount
}

class Suppliers extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get taxNumber => text().nullable()(); // New: Tax Number
  TextColumn get address => text().nullable()(); // New: Address
  TextColumn get email => text().nullable()(); // New: Email
  TextColumn get supplierType => text().withDefault(
        const Constant('LOCAL'),
      )(); // New: LOCAL, INTERNATIONAL
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))(); // New: Status
  TextColumn get balance => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get accountId =>
      text().nullable().references(GLAccounts, #id)(); // New: Linked to GL
  TextColumn get creditLimit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get currencyId => text().nullable().references(Currencies, #id)();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
}

class GlobalUnits extends Table with SyncableTable {
  TextColumn get name => text().unique()();
  TextColumn get symbol => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();
}

class Sales extends Table with SyncableTable {
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get total => text().map(const DecimalConverter())();
  TextColumn get discount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get tax => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  IntColumn get paymentMethod =>
      integer().map(const PaymentMethodConverter())();
  BoolColumn get isCredit => boolean().withDefault(const Constant(false))();
  IntColumn get status => integer()
      .map(const DocumentStatusConverter())
      .withDefault(const Constant(0))();
  TextColumn get saleType =>
      text().withDefault(const Constant('retail'))(); // retail / wholesale
  TextColumn get currencyId => text().nullable()();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
  TextColumn get shippingCost => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get otherExpenses => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  TextColumn get representativeId => text().nullable()();
  DateTimeColumn get exchangeDate => dateTime().nullable()();
  // ZATCA Fields
  TextColumn get qrCode => text().nullable()();
  TextColumn get hash => text().nullable()();
  TextColumn get signature => text().nullable()();
}

class SaleItems extends Table with SyncableTable {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get price => text().map(const DecimalConverter())();
  TextColumn get unitId => text().nullable().references(GlobalUnits, #id)();
  TextColumn get unitName => text().withDefault(const Constant('حبة'))();
  TextColumn get unitFactor => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
  TextColumn get costCenterId =>
      text().nullable().references(CostCenters, #id)(); // الحقل المضاف
}

class StockMovements extends Table with SyncableTable {
  @ReferenceName('productStockMovements')
  TextColumn get productId => text().references(Products, #id)();
  @ReferenceName('fromWarehouseStockMovements')
  TextColumn get fromWarehouseId =>
      text().nullable().references(Warehouses, #id)();
  @ReferenceName('toWarehouseStockMovements')
  TextColumn get toWarehouseId =>
      text().nullable().references(Warehouses, #id)();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get cost =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // ADDED COST
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
  DateTimeColumn get movementDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get type =>
      text()(); // TRANSFER, ADJUSTMENT, INITIAL, SALE, PURCHASE
  TextColumn get transactionId => text().nullable()(); // ADDED transactionId
  TextColumn get date => text()
      .nullable()(); // ADDED date as string or something? Wait, StockMovements already has movementDate. I will use date if needed.
  TextColumn get referenceId => text().nullable()(); // SaleId, PurchaseId, etc.
}

class Purchases extends Table with SyncableTable {
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get total => text().map(const DecimalConverter())();
  TextColumn get tax => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get discount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get landedCosts => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get shippingCost => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get otherExpenses => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get invoiceNumber => text().nullable()();
  TextColumn get purchaseType => text().withDefault(const Constant('cash'))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get time => dateTime().nullable()();
  BoolColumn get isCredit => boolean().withDefault(const Constant(false))();
  IntColumn get status => integer()
      .map(const DocumentStatusConverter())
      .withDefault(const Constant(0))(); // 0 = DRAFT
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  TextColumn get currencyId => text().nullable()();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
  TextColumn get notes => text().nullable()();
  TextColumn get referenceDocument => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
}

class PurchaseItems extends Table with SyncableTable {
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitId =>
      text().nullable()(); // New: Unit ID (e.g., carton, kilo)
  TextColumn get unitFactor =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))(); // New: Conversion to base unit
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get quantityInBaseUnit =>
      text().map(const DecimalConverter()).nullable()(); // New: Calculated base quantity
  TextColumn get unitPrice => text().map(const DecimalConverter())(); // New: Price per selected unit
  TextColumn get price => text().map(const DecimalConverter())(); // Total price (kept for compatibility)
  TextColumn get discount =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // New: Item discount
  TextColumn get discountPercent =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // New: Discount percentage
  TextColumn get tax =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // New: Tax amount
  TextColumn get taxPercent =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // New: Tax percentage
  TextColumn get landedCostShare =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // New: Share of landed costs
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
  TextColumn get batchNumber => text().nullable()(); // New
  DateTimeColumn get expiryDate => dateTime().nullable()(); // New
  TextColumn get warehouseId => text().nullable().references(
        Warehouses,
        #id,
      )(); // New: Override warehouse per item
  BoolColumn get isCarton => boolean().withDefault(const Constant(false))();
}

class Warehouses extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  TextColumn get accountId => text()
      .nullable()
      .references(GLAccounts, #id)(); // ربط المستودع بالحساب المحاسبي
  @override
  TextColumn get branchId => text().nullable().references(Branches, #id)();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

@DataClassName('ProductBatch')
class ProductBatches extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get batchNumber => text()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get quantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get initialQuantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get costPrice => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}

/// Item variants (e.g., color, size) for products with multiple attributes
class ItemVariants extends Table with SyncableTable {
  @override
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class SalesReturns extends Table with SyncableTable {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get amountReturned => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get reason => text().nullable()();
}

class SalesReturnItems extends Table with SyncableTable {
  TextColumn get salesReturnId => text().references(SalesReturns, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get price => text().map(const DecimalConverter())();
  TextColumn get unitFactor => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
}

class PurchaseReturns extends Table with SyncableTable {
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get amountReturned => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get reason => text().nullable()();
}

class PurchaseReturnItems extends Table with SyncableTable {
  TextColumn get purchaseReturnId => text().references(PurchaseReturns, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get price => text().map(const DecimalConverter())();
}

class CustomerPayments extends Table with SyncableTable {
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get amount => text().map(const DecimalConverter())();
  DateTimeColumn get paymentDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
}

class SupplierPayments extends Table with SyncableTable {
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get amount => text().map(const DecimalConverter())();
  TextColumn get remainingAmount =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // Unapplied amount
  DateTimeColumn get paymentDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(
        const Constant('COMPLETED'),
      )(); // COMPLETED, PARTIAL, CANCELLED
}

class PurchasePaymentLinks extends Table with SyncableTable {
  // Links payments to purchases for partial payment tracking
  TextColumn get paymentId => text().references(SupplierPayments, #id)();
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get amount => text().map(const DecimalConverter())(); // Amount applied to this purchase
}

class GLAccounts extends Table with SyncableTable {
  @override
  String get tableName => 'gl_accounts';

  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
  TextColumn get analyticType =>
      text().nullable()(); // جديد: صندوق، بنك، عميل، مورد، موظف، مركز تكلفة
  TextColumn get parentId => text().nullable().references(GLAccounts, #id)();
  BoolColumn get isHeader => boolean().withDefault(const Constant(false))();
  TextColumn get balance => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}

class CostCenters extends Table with SyncableTable {
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable().references(CostCenters, #id)();
  TextColumn get type => text().withDefault(const Constant('department'))(); // department, project, branch
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class GLEntries extends Table with SyncableTable {
  @override
  String get tableName => 'gl_entries';

  TextColumn get description => text()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get referenceType =>
      text().nullable()(); // Sale, Purchase, Manual, Expense
  TextColumn get referenceId => text().nullable()();
  TextColumn get status => text().withDefault(
        const Constant('DRAFT'),
      )(); // New: DRAFT, POSTED, CANCELLED
  DateTimeColumn get postedAt => dateTime().nullable()(); // New
  TextColumn get postedBy => text().nullable()(); // New
  TextColumn get currencyId => text().nullable()();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
}

class GLLines extends Table with SyncableTable {
  @override
  String get tableName => 'gl_lines';

  TextColumn get entryId => text().references(GLEntries, #id)();
  TextColumn get accountId => text().references(GLAccounts, #id)();
  TextColumn get costCenterId =>
      text().nullable().references(CostCenters, #id)();
  TextColumn get debit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get credit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get currencyId => text().nullable().references(Currencies, #id)();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
  TextColumn get memo => text().nullable()();
}

class AccountingPeriods extends Table with SyncableTable {
  TextColumn get name => text()();
  IntColumn get fiscalYear => integer()(); // New: fiscal year association
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get closedBy => text().nullable()();
  TextColumn get closingType => text().nullable()(); // DAILY, MONTHLY, YEARLY
  TextColumn get status =>
      text().withDefault(const Constant('OPEN'))(); // OPEN, CLOSED
}

class SyncQueue extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get entityTable => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().nullable()();
  
  // Enterprise Sync fields
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class InventoryAudits extends Table with SyncableTable {
  DateTimeColumn get auditDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  TextColumn get auditedBy => text().nullable()();
}

class InventoryAuditItems extends Table with SyncableTable {
  TextColumn get auditId => text().references(InventoryAudits, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get systemStock => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get actualStock => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get difference => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}

class Shifts extends Table with SyncableTable {
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get startTime => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get openingCash => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get closingCash => text().map(const DecimalConverter()).nullable()();
  TextColumn get expectedCash => text().map(const DecimalConverter()).nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isOpen => boolean().withDefault(const Constant(true))();
}

class Reconciliations extends Table with SyncableTable {
  TextColumn get accountId => text().references(GLAccounts, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get bookBalance => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get actualBalance => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get difference => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get note => text().nullable()();
}

class ReconciliationDetails extends Table {
  TextColumn get reconciliationId => text().references(Reconciliations, #id)();
  TextColumn get transactionId => text().references(AccountTransactions, #id)();
  TextColumn get statementAmount => text().map(const DecimalConverter())();
  DateTimeColumn get statementDate => dateTime()();
  TextColumn get reference => text().nullable()();
}

class AuditLogs extends Table with SyncableTable {
  TextColumn get userId => text().nullable()();
  TextColumn get action => text()(); // CREATE, UPDATE, DELETE
  TextColumn get targetEntity => text()(); // Products, Sales, etc.
  TextColumn get entityId => text()();
  TextColumn get details => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class StockTransfers extends Table with SyncableTable {
  @ReferenceName('fromWarehouseStockTransfers')
  TextColumn get fromWarehouseId => text().references(Warehouses, #id)();
  @ReferenceName('toWarehouseStockTransfers')
  TextColumn get toWarehouseId => text().references(Warehouses, #id)();
  DateTimeColumn get transferDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('COMPLETED'))();
}

class StockTransferItems extends Table with SyncableTable {
  TextColumn get transferId => text().references(StockTransfers, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get batchId => text().references(ProductBatches, #id)();
  TextColumn get quantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}

class Employees extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get employeeCode => text().unique()();
  TextColumn get jobTitle => text().nullable()();
  TextColumn get role =>
      text().withDefault(const Constant('USER'))(); // ADMIN or USER
  TextColumn get basicSalary => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  DateTimeColumn get hireDate => dateTime().nullable()();
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class PayrollEntries extends Table with SyncableTable {
  IntColumn get month => integer()();
  IntColumn get year => integer()();
  DateTimeColumn get generationDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  TextColumn get note => text().nullable()();
}

class PayrollLines extends Table with SyncableTable {
  TextColumn get payrollEntryId => text().references(PayrollEntries, #id)();
  TextColumn get employeeId => text().references(Employees, #id)();
  TextColumn get basicSalary => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get allowances => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get deductions => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get netSalary => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}

class Permissions extends Table with SyncableTable {
  TextColumn get code => text().unique()();
  TextColumn get description => text().nullable()();
}

class RolePermissions extends Table with SyncableTable {
  TextColumn get role => text()();
  TextColumn get permissionCode => text().references(Permissions, #code)();
}

class CashboxTransactions extends Table with SyncableTable {
  TextColumn get amount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get userId => text().references(Users, #id)();
}

class FinancialTransfers extends Table with SyncableTable {
  TextColumn get senderAccountId => text().references(GLAccounts, #id)();
  @ReferenceName('receiverAccountFinancialTransfers')
  TextColumn get receiverAccountId => text().references(GLAccounts, #id)();
  TextColumn get amount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();

  TextColumn get commission => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get company => text().nullable()();
  TextColumn get transferType => text()(); // CASH, BANK, CHECK
  TextColumn get checkId => text().nullable().references(Checks, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('POSTED'))();
}

class PriceLists extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get description => text().nullable()();
}

class PriceListItems extends Table with SyncableTable {
  TextColumn get priceListId => text().references(PriceLists, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get price => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get minQuantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}

class Promotions extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get type =>
      text()(); // PERCENTAGE_DISCOUNT, FIXED_DISCOUNT, BOGO (Buy One Get One)
  TextColumn get value => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // Discount amount or percentage
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get minPurchaseAmount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}

class PriceHistory extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get oldPrice => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get newPrice => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get type => text()(); // PURCHASE / SALE
}

class Currencies extends Table with SyncableTable {
  TextColumn get code => text().unique()(); // e.g., USD, YER, SAR
  TextColumn get name => text()();
  TextColumn get fractionalUnit => text().nullable()(); // فكة العملة
  IntColumn get decimalPlaces =>
      integer().withDefault(const Constant(2))(); // عدد الكسور
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
}

class ExchangeRates extends Table {
  TextColumn get fromCurrencyCode => text().references(Currencies, #code)();
  TextColumn get toCurrencyCode => text().references(Currencies, #code)();
  TextColumn get rate => text().map(const DecimalConverter())();
  DateTimeColumn get effectiveDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class UnitConversions extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitName => text()();
  TextColumn get factor =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))(); // How many of this unit equal the base unit
  BoolColumn get isBaseUnit => boolean().withDefault(const Constant(false))();
  TextColumn get buyPrice => text().map(const DecimalConverter()).nullable()(); // Unit-specific buy price
  TextColumn get sellPrice => text().map(const DecimalConverter()).nullable()(); // Unit-specific sell price
  TextColumn get barcode =>
      text().unique().nullable()(); // Barcode for this unit
}

class APInvoices extends Table with SyncableTable {
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get invoiceNumber => text()();
  DateTimeColumn get invoiceDate =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get taxAmount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get paidAmount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get status => text()
      .withDefault(const Constant('DRAFT'))(); // DRAFT, POSTED, PAID, PARTIAL
  TextColumn get notes => text().nullable()();
  TextColumn get accountId => text().nullable().references(GLAccounts, #id)();
}

class ARInvoices extends Table with SyncableTable {
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get invoiceNumber => text()();
  DateTimeColumn get invoiceDate =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get taxAmount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get paidAmount => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get status => text()
      .withDefault(const Constant('DRAFT'))(); // DRAFT, POSTED, PAID, PARTIAL
  TextColumn get notes => text().nullable()();
  TextColumn get accountId => text().nullable().references(GLAccounts, #id)();
}

class InventoryTransactions extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
  TextColumn get quantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))(); // Positive for in, negative for out
  TextColumn get type =>
      text()(); // PURCHASE, SALE, RETURN, TRANSFER, ADJUSTMENT
  TextColumn get referenceId => text()(); // PurchaseId, SaleId, etc.
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

class AccountTransactions extends Table with SyncableTable {
  TextColumn get accountId => text().references(GLAccounts, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get type => text()(); // INVOICE, PAYMENT, RETURN
  TextColumn get referenceId => text().nullable()();
  TextColumn get debit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get credit => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  BoolColumn get reconciled => boolean().withDefault(const Constant(false))();
}

class StockTakes extends Table with SyncableTable {
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status =>
      text().withDefault(const Constant('DRAFT'))(); // DRAFT, COMPLETED
  TextColumn get note => text().nullable()();
}

class StockTakeItems extends Table with SyncableTable {
  TextColumn get stockTakeId => text().references(StockTakes, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get expectedQty => real()();
  RealColumn get actualQty => real()();
  RealColumn get variance => real()();
}

class PostingProfiles extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get operationType =>
      text()(); // SALE, PURCHASE, RETURN, PAYMENT, EXPENSE, INVENTORY
  TextColumn get accountType =>
      text()(); // REVENUE, COGS, INVENTORY, RECEIVABLE, PAYABLE, TAX, CASH
  TextColumn get accountId => text().nullable().references(GLAccounts, #id)();
  TextColumn get description => text().nullable()();
  TextColumn get accountCode =>
      text().nullable()(); // Alternative: account code instead of FK
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sequence =>
      integer().withDefault(const Constant(0))(); // Order of posting lines
  TextColumn get side => text()(); // DEBIT or CREDIT
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class GoodReceivedNotes extends Table with SyncableTable {
  TextColumn get purchaseId => text().nullable().references(Purchases, #id)();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get grnNumber => text().unique()();
  DateTimeColumn get receivedDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get receivedBy => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('DRAFT'))(); // DRAFT, POSTED
}

class GoodReceivedNoteItems extends Table with SyncableTable {
  TextColumn get grnId => text().references(GoodReceivedNotes, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
}

class DeliveryNotes extends Table with SyncableTable {
  TextColumn get saleOrderId => text().references(SalesOrders, #id)();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get deliveryNumber => text().unique()();
  DateTimeColumn get deliveryDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get deliveredBy => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('DRAFT'))(); // DRAFT, POSTED
}

class DeliveryNoteItems extends Table with SyncableTable {
  TextColumn get deliveryNoteId => text().references(DeliveryNotes, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
}

class Checks extends Table with SyncableTable {
  TextColumn get checkNumber => text()();
  TextColumn get bankName => text()();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get amount => real()();
  TextColumn get type =>
      text()(); // RECEIVED (from customer), ISSUED (to supplier)
  TextColumn get status => text().withDefault(
        const Constant('PENDING'),
      )(); // PENDING, COLLECTED, BOUNCED
  TextColumn get partnerId => text().nullable()(); // Customer or Supplier ID
  TextColumn get paymentAccountId =>
      text().nullable().references(GLAccounts, #id)();
  TextColumn get note => text().nullable()();
  TextColumn get currencyId => text().nullable().references(Currencies, #id)();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).withDefault(Constant(Decimal.one.toString()))();
}

class BillOfMaterials extends Table with SyncableTable {
  @ReferenceName('finishedProduct')
  TextColumn get finishedProductId => text().references(Products, #id)();
  @ReferenceName('componentProduct')
  TextColumn get componentProductId => text().references(Products, #id)();
  RealColumn get quantity =>
      real()(); // الكمية المطلوبة من المادة الخام لإنتاج وحدة واحدة
}

class ProductionOrders extends Table with SyncableTable {
  TextColumn get finishedProductId => text().references(Products, #id)();
  RealColumn get plannedQuantity => real()();
  TextColumn get actualQuantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('PLANNED'))(); // PLANNED, IN_PROGRESS, COMPLETED, CANCELLED
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  TextColumn get note => text().nullable()();
}

class ProductionOrderItems extends Table with SyncableTable {
  TextColumn get productionOrderId => text().references(ProductionOrders, #id)();
  TextColumn get componentProductId => text().references(Products, #id)();
  RealColumn get plannedQuantity => real()();
  TextColumn get actualQuantity => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get unitCost => text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero.toString()))();
}


class PurchaseOrders extends Table with SyncableTable {
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  RealColumn get total => real()();
  TextColumn get orderNumber => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(
        const Constant('QUOTATION'),
      )(); // QUOTATION, ORDER, DELIVERED, INVOICED, CANCELLED
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  TextColumn get notes => text().nullable()();
}

class PurchaseOrderItems extends Table with SyncableTable {
  TextColumn get orderId => text().references(PurchaseOrders, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  TextColumn get unitId => text().nullable()();
}

class SalesOrders extends Table with SyncableTable {
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  RealColumn get total => real()();
  TextColumn get orderNumber => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(
        const Constant('QUOTATION'),
      )(); // QUOTATION, ORDER, DELIVERED, INVOICED, CANCELLED
  TextColumn get notes => text().nullable()();
}

class SalesOrderItems extends Table with SyncableTable {
  TextColumn get orderId => text().references(SalesOrders, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  TextColumn get unitId => text().nullable()();
}

class CustomerPaymentLinks extends Table with SyncableTable {
  // Links customer payments to sales for invoice-wise tracking
  TextColumn get paymentId => text().references(CustomerPayments, #id)();
  TextColumn get saleId => text().references(Sales, #id)();
  RealColumn get amount => real()(); // Amount applied to this sale
}

@DriftDatabase(
  tables: [
    Branches,
    Users,
    Categories,
    Products,
    Customers,
    Suppliers,
    Sales,
    SaleItems,
    Purchases,
    PurchaseItems,
    PurchaseOrders,
    PurchaseOrderItems,
    SalesOrders,
    SalesOrderItems,
    ProductionOrders,
    ProductionOrderItems,
    SalesReturns,
    SalesReturnItems,
    PurchaseReturns,
    PurchaseReturnItems,
    CustomerPayments,
    SupplierPayments,
    PurchasePaymentLinks,
    CustomerPaymentLinks,
    SyncQueue,
    GLAccounts,
    CostCenters,
    GLEntries,
    GLLines,
    AccountingPeriods,
    InventoryAudits,
    InventoryAuditItems,
    Shifts,
    Reconciliations,
    AuditLogs,
    Warehouses,
    ProductBatches,
    ItemVariants,
    StockTransfers,
    StockTransferItems,
    Employees,
    PayrollEntries,
    PayrollLines,
    Permissions,
    RolePermissions,
    CashboxTransactions,
    FinancialTransfers,
    PriceLists,
    PriceListItems,
    Promotions,
    Currencies,
    PriceHistory,
    UnitConversions,
    StockTakes,
    StockTakeItems,
    Checks,
    BillOfMaterials,
    InventoryTransactions,
    AccountTransactions,
    PostingProfiles,
    GlobalUnits,
    StockMovements,
    ProductUnits,
    APInvoices,
    ARInvoices,
    GoodReceivedNotes,
    GoodReceivedNoteItems,
    DeliveryNotes,
    DeliveryNoteItems,
    AppConfigTable,
    // Advanced Accounting Tables
    AccAssetCategories,
    FixedAssets,
    AccAssetDepreciationLogs,
    AccAssetDisposals,
    HREmployees,
    HRPayrollRuns,
    HRPayrollDetails,
    HRAdditionalDeductions,
    ExchangeRates,
    AccExchangeRates,
    AccBudgets,
    AccBankStatements,
    AccBankStatementLines,
    AccAuditLogs,
    AccCurrencies,
  ],
  daos: [
    ProductsDao,
    SalesDao,
    CustomersDao,
    AccountingDao,
    UsersDao,
    SuppliersDao,
    PurchasesDao,
    BomDao,
    WarehousesDao,
    GlobalUnitsDao,
    ProductUnitsDao,
    AuditDao,
    StockMovementDao,
    CashboxDao,
    TransfersDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 41;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Verify tables were created
          final tables = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
          ).get();
          debugPrint("DB: Created ${tables.length} tables on first run:");
          for (final t in tables) {
            debugPrint("DB:   - ${t.data['name']}");
          }
          // Explicitly set schema version to avoid stale PRAGMA user_version issues
          await customStatement("PRAGMA user_version = $schemaVersion");
          debugPrint("DB: PRAGMA user_version set to $schemaVersion.");
          // Seed data immediately after creation in the same transaction
          await seedData();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Direct migration instead of metadata-heavy reflection
          if (from < 32) {
            await m.createIndex(Index('products_sku_idx',
                'CREATE INDEX products_sku_idx ON products (sku)'));
            await m.createIndex(Index('products_barcode_idx',
                'CREATE INDEX products_barcode_idx ON products (barcode)'));
            await m.createIndex(Index('sale_items_sale_id_idx',
                'CREATE INDEX sale_items_sale_id_idx ON sale_items (sale_id)'));
            await m.createIndex(Index('purchase_items_purchase_id_idx',
                'CREATE INDEX purchase_items_purchase_id_idx ON purchase_items (purchase_id)'));
            await m.createIndex(Index('gl_lines_entry_id_idx',
                'CREATE INDEX gl_lines_entry_id_idx ON gl_lines (entry_id)'));
            await m.createIndex(Index('gl_lines_account_id_idx',
                'CREATE INDEX gl_lines_account_id_idx ON gl_lines (account_id)'));
            await m.createIndex(Index('stock_movements_product_id_idx',
                'CREATE INDEX stock_movements_product_id_idx ON stock_movements (product_id)'));
          }
          if (from < 33) {
            try {
              await m.addColumn(products, products.valuationMethod);
            } catch (_) {}
            try {
              await m.addColumn(products, products.allowFreeQty);
            } catch (_) {}
            try {
              await m.addColumn(products, products.isService);
            } catch (_) {}
          }
          if (from < 34) {
            // Version 34: Update GRN table - add purchaseId and supplierId columns
            try {
              await m.addColumn(
                  goodReceivedNotes, goodReceivedNotes.purchaseId);
            } catch (_) {}
            try {
              await m.addColumn(
                  goodReceivedNotes, goodReceivedNotes.supplierId);
            } catch (_) {}
            // Note: purchaseOrderId will be kept for backward compatibility but deprecated
          }
          if (from < 35) {
            // Version 35: Add AppConfigTable for dynamic settings
            try {
              await m.createTable(appConfigTable);
            } catch (_) {}
          }
          if (from < 36) {
            // Version 36: Add shippingCost, otherExpenses, warehouseId, representativeId to Sales
            try {
              await m.addColumn(sales, sales.shippingCost);
            } catch (_) {}
            try {
              await m.addColumn(sales, sales.otherExpenses);
            } catch (_) {}
            try {
              await m.addColumn(sales, sales.warehouseId);
            } catch (_) {}
            try {
              await m.addColumn(sales, sales.representativeId);
            } catch (_) {}
          }
          if (from < 37) {
            // Version 37: Add FinancialTransfers table
            try {
              await m.createTable(financialTransfers);
            } catch (_) {}
          }
          if (from < 38) {
            // Version 38: Add Production tables
            try {
              await m.createTable(productionOrders);
              await m.createTable(productionOrderItems);
            } catch (_) {}
          }
          if (from < 39) {
            // Version 39: Add query indexes for high-volume ERP screens.
            await ensurePerformanceIndexes();
          }
          // Version 40: Currency unification + performance indexes + decimal precision fixes
          if (from < 40) {
            await _migrateToV40(m);
          }
          // Version 41: User sessions, password hashing, reconciliation details, decimal columns
          if (from < 41) {
            await _migrateToV41(m);
          }
        },
        beforeOpen: (details) async {
          debugPrint("DB: beforeOpen started. Details: ${details.wasCreated ? 'Created' : 'Opened'}");

          // Apply encryption key. The key is written inline because SQLite
          // does not support placeholders (?) in PRAGMA statements.
          if (!SecurityService.useFakeKeyForTesting) {
            try {
              final key = await SecurityService.getDatabaseKey();
              final escapedKey = key.replaceAll("'", "''");

              // IMPORTANT: Set key first to initialize the cipher correctly.
              debugPrint("DB: Applying encryption key...");
              await customStatement("PRAGMA key = '$escapedKey'");

              // Then set cipher parameters.
              debugPrint("DB: Setting cipher parameters...");
              await customStatement('PRAGMA cipher_page_size = 4096');
              await customStatement('PRAGMA kdf_iter = 64000');

              // Verification query to ensure key worked
              debugPrint("DB: Verifying encryption...");
              await customStatement('SELECT count(*) FROM sqlite_master;');
              debugPrint("DB: Encryption verified successfully.");
            } catch (e) {
              debugPrint("DB ERROR during encryption setup: $e");
              if (e.toString().contains('code 26') || e.toString().contains('file is not a database')) {
                debugPrint("DB FATAL: Cannot decrypt database (error 26).");
                final dbFolder = await getApplicationDocumentsDirectory();
                final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
                final backupPath = "${file.path}.FAILED_DECRYPT_${DateTime.now().millisecondsSinceEpoch}";
                
                if (await file.exists()) {
                   await file.rename(backupPath);
                   debugPrint("DB: Renamed corrupted/unreadable DB to $backupPath for analysis.");
                }
                throw Exception('فشل فتح قاعدة البيانات المشفرة. تم حفظ الملف التالف للمراجعة. (Error 26)');
              }
              rethrow;
            }
          }

          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA synchronous = NORMAL;');
          await ensurePerformanceIndexes();
          // Existing databases might predate critical seed data. Keep this
          // idempotent so lookups (currencies/branches/GL headers) are never empty.
          await ensureCoreReferenceData();

          // Log schema version and table list for verification
          final versionResult = await customSelect("PRAGMA user_version").get();
          debugPrint("DB: Schema version: ${versionResult.first.data.values.first}");
          final tables = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
          ).get();
          debugPrint("DB: Database has ${tables.length} tables:");
          for (final t in tables) {
            debugPrint("DB:   - ${t.data['name']}");
          }
        },      );

  static const List<String> _performanceIndexStatements = [
    'CREATE INDEX IF NOT EXISTS products_sku_idx ON products (sku)',
    'CREATE INDEX IF NOT EXISTS products_barcode_idx ON products (barcode)',
    'CREATE INDEX IF NOT EXISTS products_category_id_idx ON products (category_id)',
    'CREATE INDEX IF NOT EXISTS products_supplier_id_idx ON products (supplier_id)',
    'CREATE INDEX IF NOT EXISTS products_is_active_idx ON products (is_active)',
    'CREATE INDEX IF NOT EXISTS product_units_product_id_idx ON product_units (product_id)',
    'CREATE INDEX IF NOT EXISTS product_units_barcode_idx ON product_units (barcode)',
    'CREATE INDEX IF NOT EXISTS product_batches_product_warehouse_idx '
        'ON product_batches (product_id, warehouse_id)',
    'CREATE INDEX IF NOT EXISTS product_batches_expiry_date_idx '
        'ON product_batches (expiry_date)',
    'CREATE INDEX IF NOT EXISTS sale_items_sale_id_idx ON sale_items (sale_id)',
    'CREATE INDEX IF NOT EXISTS sale_items_product_id_idx ON sale_items (product_id)',
    'CREATE INDEX IF NOT EXISTS sales_customer_id_idx ON sales (customer_id)',
    'CREATE INDEX IF NOT EXISTS sales_created_at_idx ON sales (created_at)',
    'CREATE INDEX IF NOT EXISTS sales_status_idx ON sales (status)',
    'CREATE INDEX IF NOT EXISTS purchase_items_purchase_id_idx '
        'ON purchase_items (purchase_id)',
    'CREATE INDEX IF NOT EXISTS purchase_items_product_id_idx '
        'ON purchase_items (product_id)',
    'CREATE INDEX IF NOT EXISTS purchases_supplier_id_idx ON purchases (supplier_id)',
    'CREATE INDEX IF NOT EXISTS purchases_date_idx ON purchases (date)',
    'CREATE INDEX IF NOT EXISTS purchases_status_idx ON purchases (status)',
    'CREATE INDEX IF NOT EXISTS gl_entries_date_idx ON gl_entries (date)',
    'CREATE INDEX IF NOT EXISTS gl_entries_reference_idx '
        'ON gl_entries (reference_type, reference_id)',
    'CREATE INDEX IF NOT EXISTS gl_entries_status_idx ON gl_entries (status)',
    'CREATE INDEX IF NOT EXISTS gl_lines_entry_id_idx ON gl_lines (entry_id)',
    'CREATE INDEX IF NOT EXISTS gl_lines_account_id_idx ON gl_lines (account_id)',
    'CREATE INDEX IF NOT EXISTS gl_lines_cost_center_id_idx '
        'ON gl_lines (cost_center_id)',
    'CREATE INDEX IF NOT EXISTS stock_movements_product_id_idx '
        'ON stock_movements (product_id)',
    'CREATE INDEX IF NOT EXISTS stock_movements_reference_id_idx '
        'ON stock_movements (reference_id)',
    'CREATE INDEX IF NOT EXISTS stock_movements_movement_date_idx '
        'ON stock_movements (movement_date)',
    'CREATE INDEX IF NOT EXISTS stock_movements_type_idx ON stock_movements (type)',
    'CREATE INDEX IF NOT EXISTS customer_payments_customer_id_idx '
        'ON customer_payments (customer_id)',
    'CREATE INDEX IF NOT EXISTS customer_payments_payment_date_idx '
        'ON customer_payments (payment_date)',
    'CREATE INDEX IF NOT EXISTS supplier_payments_supplier_id_idx '
        'ON supplier_payments (supplier_id)',
    'CREATE INDEX IF NOT EXISTS supplier_payments_payment_date_idx '
        'ON supplier_payments (payment_date)',
    'CREATE INDEX IF NOT EXISTS audit_logs_timestamp_idx ON audit_logs (timestamp)',
    'CREATE INDEX IF NOT EXISTS audit_logs_target_entity_idx '
        'ON audit_logs (target_entity)',
    'CREATE INDEX IF NOT EXISTS sync_queue_status_idx ON sync_queue (status)',
    'CREATE INDEX IF NOT EXISTS sync_queue_pending_entity_idx '
        'ON sync_queue (entity_table, entity_id, operation, status)',
  ];

  Future<void> ensurePerformanceIndexes() async {
    for (final statement in _performanceIndexStatements) {
      await customStatement(statement);
    }
  }

  // Inspect HR tables and log what would be converted during a dry run.
  // Used during onUpgrade (safe/no-op) and dry-run mode. Never modifies data.
  Future<void> _backfillHrUuidIdsSafe({bool verbose = false}) async {
    try {
      final tables = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'h_r_%';"
      ).get();
      if (tables.isEmpty) {
        if (verbose) {
          await customStatement("-- HR UUID backfill: no HR tables found.");
        }
        return;
      }

      if (verbose) {
        await customStatement("-- HR UUID backfill: inspecting tables");
      }

      // Count numeric IDs in h_r_employees
      try {
        final empResult = await customSelect(
          "SELECT COUNT(*) AS cnt FROM h_r_employees WHERE id GLOB '[0-9]*'"
        ).get();
        final empNumericCount = empResult.isNotEmpty
            ? (empResult.first.data['cnt'] as int?) ?? 0
            : 0;
        if (verbose) {
          await customStatement(
            "-- h_r_employees: $empNumericCount record(s) with numeric IDs",
          );
        }
      } catch (_) {
        // Table may not exist yet
      }

      // Count numeric IDs in h_r_payroll_runs
      try {
        final runResult = await customSelect(
          "SELECT COUNT(*) AS cnt FROM h_r_payroll_runs WHERE id GLOB '[0-9]*'"
        ).get();
        final runNumericCount = runResult.isNotEmpty
            ? (runResult.first.data['cnt'] as int?) ?? 0
            : 0;
        if (verbose) {
          await customStatement(
            "-- h_r_payroll_runs: $runNumericCount record(s) with numeric IDs",
          );
        }
      } catch (_) {
        // Table may not exist yet
      }

      await customStatement(
        "-- HR UUID backfill skipped in automated onUpgrade. "
        "Run offline migration if needed.",
      );
    } catch (_) {
      // Intentionally swallow errors to avoid breaking migrations.
    }
  }

  // Detect and convert legacy numeric IDs in HR tables to UUID strings.
  // Processes in batches with audit logging and rollback support.
  // Stores old->new ID mappings in _hr_backfill_audit for rollback.
  // ignore: unused_element
  Future<void> _backfillHrUuidIds({int batchSize = 50}) async {
    try {
      final tables = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'h_r_%';"
      ).get();
      if (tables.isEmpty) return;

      await _createBackfillAuditTable();
      await customStatement('PRAGMA foreign_keys = OFF;');

      // Employees — process in batches
      final empRows =
          await customSelect('SELECT id FROM h_r_employees').get();
      int empConverted = 0;
      final empTotal = empRows.length;
      final empBatches =
          (empTotal + batchSize - 1) ~/ batchSize;

      for (int i = 0; i < empTotal; i += batchSize) {
        final batch = empRows.skip(i).take(batchSize).toList();
        final batchNum = i ~/ batchSize + 1;
        try {
          for (final row in batch) {
            final oldIdRaw = row.data['id'];
            if (oldIdRaw == null) continue;
            final oldIdStr = oldIdRaw.toString();
            if (RegExp(r'^\d+$').hasMatch(oldIdStr)) {
              final newId = const Uuid().v4();
              await customStatement(
                'UPDATE h_r_employees SET id = ? WHERE id = ?',
                [newId, oldIdStr],
              );
              await customStatement(
                'UPDATE h_r_payroll_details SET employee_id = ? WHERE employee_id = ?',
                [newId, oldIdStr],
              );
              await customStatement(
                'UPDATE h_r_additional_deductions SET employee_id = ? WHERE employee_id = ?',
                [newId, oldIdStr],
              );
              await customStatement(
                'INSERT INTO _hr_backfill_audit '
                '(table_name, old_id, new_id) VALUES (?, ?, ?)',
                ['h_r_employees', oldIdStr, newId],
              );
              empConverted++;
            }
          }
          await customStatement(
            "-- Employee batch $batchNum/$empBatches: "
            "$empConverted converted so far",
          );
        } catch (batchErr) {
          await customStatement(
            "-- ERROR in employee batch $batchNum/$empBatches: "
            "${batchErr.toString().replaceAll("'", "''")}",
          );
        }
      }

      // Payroll runs — process in batches
      final runRows =
          await customSelect('SELECT id FROM h_r_payroll_runs').get();
      int runConverted = 0;
      final runTotal = runRows.length;
      final runBatches =
          (runTotal + batchSize - 1) ~/ batchSize;

      for (int i = 0; i < runTotal; i += batchSize) {
        final batch = runRows.skip(i).take(batchSize).toList();
        final batchNum = i ~/ batchSize + 1;
        try {
          for (final row in batch) {
            final oldIdRaw = row.data['id'];
            if (oldIdRaw == null) continue;
            final oldIdStr = oldIdRaw.toString();
            if (RegExp(r'^\d+$').hasMatch(oldIdStr)) {
              final newId = const Uuid().v4();
              await customStatement(
                'UPDATE h_r_payroll_runs SET id = ? WHERE id = ?',
                [newId, oldIdStr],
              );
              await customStatement(
                'UPDATE h_r_payroll_details SET payroll_run_id = ? WHERE payroll_run_id = ?',
                [newId, oldIdStr],
              );
              await customStatement(
                'INSERT INTO _hr_backfill_audit '
                '(table_name, old_id, new_id) VALUES (?, ?, ?)',
                ['h_r_payroll_runs', oldIdStr, newId],
              );
              runConverted++;
            }
          }
          await customStatement(
            "-- Payroll run batch $batchNum/$runBatches: "
            "$runConverted converted so far",
          );
        } catch (batchErr) {
          await customStatement(
            "-- ERROR in payroll run batch $batchNum/$runBatches: "
            "${batchErr.toString().replaceAll("'", "''")}",
          );
        }
      }

      await customStatement(
        "-- HR backfill complete: "
        "$empConverted employees, $runConverted payroll runs",
      );
      await customStatement('PRAGMA foreign_keys = ON;');
    } catch (e) {
      try {
        await customStatement(
          "-- HR ID backfill failed: "
          "${e.toString().replaceAll("'", "''")} ",
        );
      } catch (_) {}
      try {
        await customStatement('PRAGMA foreign_keys = ON;');
      } catch (_) {}
    }
  }

  /// Public entrypoint for running the HR backfill migration from an external
  /// script. When [dryRun] is true, the method will not perform destructive
  /// updates and will instead write SQL comments into the database for audit.
  /// Set [verbose] to true to emit debug information via customStatement.
  /// When [rollback] is true, reverses a previous backfill using stored mappings.
  /// [batchSize] controls how many rows are processed per batch for progress
  /// tracking and error isolation.
  Future<void> runHrBackfill({
    bool dryRun = true,
    bool verbose = false,
    int batchSize = 50,
    bool rollback = false,
  }) async {
    if (rollback) {
      if (verbose) {
        await customStatement("-- HR backfill: rolling back previous migration");
      }
      await _rollbackHrBackfill(verbose: verbose);
      return;
    }

    if (dryRun) {
      if (verbose) {
        await customStatement(
          "-- HR backfill: dryRun=true; inspecting HR tables",
        );
      }
      await _backfillHrUuidIdsSafe(verbose: verbose);
      return;
    }

    await customStatement(
      "-- HR backfill: starting live migration (batchSize=$batchSize)",
    );
    await _backfillHrUuidIds(batchSize: batchSize);
  }

  // Create an audit table that stores old->new ID mappings so the
  // migration can be rolled back if necessary.
  Future<void> _createBackfillAuditTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS _hr_backfill_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        old_id TEXT NOT NULL,
        new_id TEXT NOT NULL,
        converted_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // Reverse a previous HR UUID backfill by restoring old IDs from the
  // _hr_backfill_audit table. Cleans up the audit table on completion.
  Future<void> _rollbackHrBackfill({bool verbose = false}) async {
    try {
      // Check if audit table has any entries
      final countResult = await customSelect(
        'SELECT COUNT(*) AS cnt FROM _hr_backfill_audit',
      ).get();
      final total = countResult.isNotEmpty
          ? (countResult.first.data['cnt'] as int?) ?? 0
          : 0;
      if (total == 0) {
        if (verbose) {
          await customStatement(
            "-- HR rollback: no audit entries found; nothing to roll back",
          );
        }
        return;
      }

      if (verbose) {
        await customStatement(
          "-- HR rollback: reversing $total ID mappings",
        );
      }

      await customStatement('PRAGMA foreign_keys = OFF;');

      // Restore employee IDs
      final employeeMappings = await customSelect(
        "SELECT old_id, new_id FROM _hr_backfill_audit "
        "WHERE table_name = 'h_r_employees'",
      ).get();
      int empRestored = 0;
      for (final mapping in employeeMappings) {
        final oldId = mapping.data['old_id'].toString();
        final newId = mapping.data['new_id'].toString();
        await customStatement(
          'UPDATE h_r_employees SET id = ? WHERE id = ?',
          [oldId, newId],
        );
        await customStatement(
          'UPDATE h_r_payroll_details SET employee_id = ? WHERE employee_id = ?',
          [oldId, newId],
        );
        await customStatement(
          'UPDATE h_r_additional_deductions SET employee_id = ? WHERE employee_id = ?',
          [oldId, newId],
        );
        empRestored++;
      }

      // Restore payroll run IDs
      final runMappings = await customSelect(
        "SELECT old_id, new_id FROM _hr_backfill_audit "
        "WHERE table_name = 'h_r_payroll_runs'",
      ).get();
      int runRestored = 0;
      for (final mapping in runMappings) {
        final oldId = mapping.data['old_id'].toString();
        final newId = mapping.data['new_id'].toString();
        await customStatement(
          'UPDATE h_r_payroll_runs SET id = ? WHERE id = ?',
          [oldId, newId],
        );
        await customStatement(
          'UPDATE h_r_payroll_details SET payroll_run_id = ? WHERE payroll_run_id = ?',
          [oldId, newId],
        );
        runRestored++;
      }

      // Clean up audit table
      await customStatement('DELETE FROM _hr_backfill_audit');

      await customStatement('PRAGMA foreign_keys = ON;');

      if (verbose) {
        await customStatement(
          "-- HR rollback complete: "
          "$empRestored employees, $runRestored payroll runs restored",
        );
      }
    } catch (e) {
      try {
        await customStatement(
          "-- HR rollback failed: "
          "${e.toString().replaceAll("'", "''")}",
        );
      } catch (_) {}
      try {
        await customStatement('PRAGMA foreign_keys = ON;');
      } catch (_) {}
      rethrow;
    }
  }

  Future<int> getUnsyncedCount() async {
    final countExp = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  Future<double> calculateTotalInventoryValue() async {
    final query = selectOnly(productBatches)
      ..addColumns([productBatches.quantity, productBatches.costPrice]);
    final rows = await query.get();
    Decimal total = Decimal.zero;
    for (final row in rows) {
      final qty = (row.read(productBatches.quantity) as Decimal?) ?? Decimal.zero;
      final cost = (row.read(productBatches.costPrice) as Decimal?) ?? Decimal.zero;
      total += qty * cost;
    }
    return total.toDouble();
  }

  Stream<List<Product>> watchLowStockProducts() {
    return (select(products)
          ..where((p) => p.stock.isSmallerOrEqual(p.alertLimit)))
        .watch();
  }

  Future<void> seedData() async {
    await transaction(() async {
      // 1. Branches
      final branchesCount = await (selectOnly(branches)
            ..addColumns([branches.id.count()]))
          .map((row) => row.read(branches.id.count()))
          .getSingle();
      if ((branchesCount ?? 0) == 0) {
        await into(branches).insert(
          BranchesCompanion.insert(
            name: 'الفرع الرئيسي',
            code: 'MAIN',
            isActive: const Value(true),
          ),
        );
      }

      // 2. Currencies
      await ensureDefaultCurrencies();

      // 3. Warehouses
      final warehousesCount = await (selectOnly(warehouses)
            ..addColumns([warehouses.id.count()]))
          .map((row) => row.read(warehouses.id.count()))
          .getSingle();
      if ((warehousesCount ?? 0) == 0) {
        await into(warehouses).insert(
          WarehousesCompanion.insert(
            name: 'المستودع الرئيسي',
            isDefault: const Value(true),
          ),
        );
      }

      // 4. Categories
      final categoriesCount = await (selectOnly(categories)
            ..addColumns([categories.id.count()]))
          .map((row) => row.read(categories.id.count()))
          .getSingle();
      if ((categoriesCount ?? 0) == 0) {
        await batch((b) {
          b.insert(
              categories,
              CategoriesCompanion.insert(
                  name: 'مواد غذائية', code: const Value('FOOD')));
          b.insert(
              categories,
              CategoriesCompanion.insert(
                  name: 'منظفات', code: const Value('CLEAN')));
        });
      }

      // 5. GL Accounts must exist before suppliers/customers create linked accounts.
      await _seedGLAccounts();

      // 6. Suppliers
      final suppliersCount = await (selectOnly(suppliers)
            ..addColumns([suppliers.id.count()]))
          .map((row) => row.read(suppliers.id.count()))
          .getSingle();
      if ((suppliersCount ?? 0) == 0) {
        await into(suppliers).insert(
          SuppliersCompanion.insert(
              name: 'مورد عام', isActive: const Value(true)),
        );
      }

      // 7. Customers
      final customersCount = await (selectOnly(customers)
            ..addColumns([customers.id.count()]))
          .map((row) => row.read(customers.id.count()))
          .getSingle();
      if ((customersCount ?? 0) == 0) {
        await into(customers).insert(
          CustomersCompanion.insert(
            name: 'عميل نقدي',
            isQuickCustomer: const Value(true),
            isActive: const Value(true),
          ),
        );
      }

      // 9. Posting Profiles
      await _seedPostingProfiles();

      // 10. Permissions and role defaults
      await seedSecurityData();

      // 11. Accounting Periods
      await ensureAccountingPeriodsForYear(DateTime.now().year);
    });
  }

  Future<void> ensureCoreReferenceData() async {
    await transaction(() async {
      await ensureDefaultBranch();
      await ensureDefaultCurrencies();
      await _seedGLAccounts();
    });
  }

  Future<String> ensureDefaultBranch() async {
    final existingMain = await (select(branches)
          ..where((b) => b.code.equals('MAIN')))
        .getSingleOrNull();
    if (existingMain != null) {
      await _upsertAppConfigValue('default_branch_id', existingMain.id);
      return existingMain.id;
    }

    final firstBranch = await (select(branches)..limit(1)).getSingleOrNull();
    if (firstBranch != null) {
      await _upsertAppConfigValue('default_branch_id', firstBranch.id);
      return firstBranch.id;
    }

    final branchId = const Uuid().v4();
    await into(branches).insert(
      BranchesCompanion.insert(
        id: Value(branchId),
        name: 'الفرع الرئيسي',
        code: 'MAIN',
        isActive: const Value(true),
      ),
    );
    await _upsertAppConfigValue('default_branch_id', branchId);
    return branchId;
  }

  Future<void> ensureDefaultCurrencies() async {
    final countExp = currencies.id.count();
    final currenciesCount = await (selectOnly(currencies)..addColumns([countExp]))
        .map((row) => row.read(countExp))
        .getSingle();

    final defaults = <CurrenciesCompanion>[
      CurrenciesCompanion.insert(
        id: const Value('YER'),
        code: 'YER',
        name: 'ريال يمني',
        fractionalUnit: const Value('فلس'),
        isBase: Value((currenciesCount ?? 0) == 0),
        exchangeRate: Value(Decimal.one),
      ),
      CurrenciesCompanion.insert(
        id: const Value('SAR'),
        code: 'SAR',
        name: 'ريال سعودي',
        fractionalUnit: const Value('هللة'),
        isBase: const Value(false),
        exchangeRate: Value(Decimal.parse('0.14')),
      ),
      CurrenciesCompanion.insert(
        id: const Value('USD'),
        code: 'USD',
        name: 'دولار أمريكي',
        fractionalUnit: const Value('سنت'),
        isBase: const Value(false),        exchangeRate: Value(Decimal.parse('0.0004')),
      ),
    ];

    for (final currency in defaults) {
      final code = currency.code.value;
      final exists = await (select(currencies)..where((c) => c.code.equals(code)))
          .getSingleOrNull();
      if (exists == null) {
        await into(currencies).insert(currency);
      }
    }

    final hasBase = await (select(currencies)..where((c) => c.isBase.equals(true)))
        .getSingleOrNull();
    if (hasBase == null) {
      await (update(currencies)..where((c) => c.code.equals('YER'))).write(
        const CurrenciesCompanion(isBase: Value(true)),
      );
    }
  }

  Future<void> _upsertAppConfigValue(String key, String value) async {
    await into(appConfigTable).insert(
      AppConfigTableCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> ensureAccountingPeriodsForYear(int year) async {
    final existingPeriods = await select(accountingPeriods).get();

    for (var month = 1; month <= 12; month++) {
      final alreadyExists = existingPeriods.any(
        (period) =>
            period.startDate.year == year && period.startDate.month == month,
      );
      if (alreadyExists) continue;

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59, 999);
      await into(accountingPeriods).insert(
        AccountingPeriodsCompanion.insert(
          name: '${_arabicMonthName(month)} $year',
          fiscalYear: year,
          startDate: startDate,
          endDate: endDate,
          status: const Value('OPEN'),
        ),
      );
    }
  }

  String _arabicMonthName(int month) {
    const monthNames = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return monthNames[month - 1];
  }

  Future<void> seedSecurityData() async {
    const permissionsToSeed = <String, String>{
      'POST_SALE': 'ترحيل المبيعات',
      'POST_PURCHASE': 'ترحيل المشتريات',
      'POST_SALE_RETURN': 'ترحيل مرتجعات المبيعات',
      'POST_PURCHASE_RETURN': 'ترحيل مرتجعات المشتريات',
      'DELETE_INVOICE': 'حذف الفواتير',
      'VOID_TRANSACTION': 'إلغاء العمليات',
      'MANAGE_USERS': 'إدارة المستخدمين',
      'VIEW_REPORTS': 'عرض التقارير',
      'MANAGE_SETTINGS': 'إدارة الإعدادات',
      'MANAGE_INVENTORY': 'إدارة المخزون',
      'APPROVE_DISCOUNT': 'اعتماد الخصومات',
      'EDIT_TAX': 'إدخال وتعديل الضريبة يدويًا',
    };

    const rolePermissionsToSeed = <String, List<String>>{
      'admin': [
        'POST_SALE',
        'POST_PURCHASE',
        'POST_SALE_RETURN',
        'POST_PURCHASE_RETURN',
        'DELETE_INVOICE',
        'VOID_TRANSACTION',
        'MANAGE_USERS',
        'VIEW_REPORTS',
        'MANAGE_SETTINGS',
        'MANAGE_INVENTORY',
        'APPROVE_DISCOUNT',
        'EDIT_TAX',
      ],
      'manager': [
        'POST_SALE',
        'POST_PURCHASE',
        'POST_SALE_RETURN',
        'POST_PURCHASE_RETURN',
        'VIEW_REPORTS',
        'MANAGE_INVENTORY',
        'APPROVE_DISCOUNT',
        'EDIT_TAX',
      ],
      'cashier': [
        'POST_SALE',
        'POST_SALE_RETURN',
      ],
    };

    await transaction(() async {
      await batch((b) {
        for (final entry in permissionsToSeed.entries) {
          b.insert(
            permissions,
            PermissionsCompanion.insert(
              code: entry.key,
              description: Value(entry.value),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      // Role permissions - check existence efficiently
      final existingRolePerms = await select(rolePermissions).get();
      
      await batch((b) {
        for (final roleEntry in rolePermissionsToSeed.entries) {
          for (final permissionCode in roleEntry.value) {
            final alreadyExists = existingRolePerms.any(
              (rp) => rp.role == roleEntry.key && rp.permissionCode == permissionCode,
            );
            if (!alreadyExists) {
              b.insert(
                rolePermissions,
                RolePermissionsCompanion.insert(
                  role: roleEntry.key,
                  permissionCode: permissionCode,
                ),
              );
            }
          }
        }
      });
    });
  }

  Future<void> _migrateToV40(Migrator m) async {
    // 1. Currency unification: Copy AccCurrencies data into Currencies
    try {
      await customStatement('''
        INSERT OR IGNORE INTO currencies (id, code, name, exchange_rate, is_base, created_at, updated_at, sync_status)
        SELECT 
          acc.code,
          acc.code,
          acc.name,
          acc.exchange_rate,
          COALESCE((SELECT c.is_base FROM currencies c WHERE c.code = acc.code), acc.is_base),
          acc.created_at,
          datetime('now'),
          1
        FROM acc_currencies acc
        WHERE NOT EXISTS (SELECT 1 FROM currencies c WHERE c.code = acc.code)
      ''');
    } catch (_) {}

    // 2. Create exchange_rates table if not exists
    try {
      await customStatement('''
        CREATE TABLE IF NOT EXISTS exchange_rates (
          id TEXT PRIMARY KEY,
          from_currency_code TEXT NOT NULL REFERENCES currencies(code),
          to_currency_code TEXT NOT NULL REFERENCES currencies(code),
          rate TEXT NOT NULL DEFAULT '1.0',
          effective_date TEXT NOT NULL,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
    } catch (_) {}

    // 3. Migrate AccExchangeRates data to exchange_rates
    try {
      await customStatement('''
        INSERT OR IGNORE INTO exchange_rates (id, from_currency_code, to_currency_code, rate, effective_date, created_at)
        SELECT 
          hex(randomblob(16)),
          COALESCE((SELECT code FROM acc_currencies WHERE id = aer.from_currency_id), ''),
          COALESCE((SELECT code FROM acc_currencies WHERE id = aer.to_currency_id), ''),
          aer.rate,
          aer.effective_date,
          aer.created_at
        FROM acc_exchange_rates aer
        WHERE EXISTS (SELECT 1 FROM acc_currencies WHERE id = aer.from_currency_id)
          AND EXISTS (SELECT 1 FROM acc_currencies WHERE id = aer.to_currency_id)
      ''');
    } catch (_) {}

    // 4. Performance indexes
    try {
      await customStatement('CREATE INDEX IF NOT EXISTS idx_gl_lines_entry_account ON gl_lines(entry_id, account_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_gl_lines_account_date ON gl_lines(account_id, entry_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_gl_entries_date ON gl_entries(date)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_gl_entries_ref ON gl_entries(reference_type, reference_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_sales_customer_status ON sales(customer_id, status)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_purchases_supplier_status ON purchases(supplier_id, status)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_inventory_transactions_product ON inventory_transactions(product_id, warehouse_id, type)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_account_transactions_account ON account_transactions(account_id, date)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_product_batches_product ON product_batches(product_id, warehouse_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_customer_payments_customer ON customer_payments(customer_id, payment_date)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_supplier_payments_supplier ON supplier_payments(supplier_id, payment_date)');
    } catch (_) {}

    // 5. Add exchange_date to Sales table for multicurrency tracking
    try {
      await m.addColumn(sales, sales.exchangeDate);
    } catch (_) {}

    // 6. Add missing columns to Suppliers
    try {
      await m.addColumn(suppliers, suppliers.creditLimit);
    } catch (_) {}
    try {
      await m.addColumn(suppliers, suppliers.currencyId);
    } catch (_) {}
    try {
      await m.addColumn(suppliers, suppliers.exchangeRate);
    } catch (_) {}
  }

  Future<void> _migrateToV41(Migrator m) async {
    // 1. Create user_sessions table
    try {
      await customStatement('''
        CREATE TABLE IF NOT EXISTS user_sessions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id),
          token TEXT UNIQUE NOT NULL,
          login_at TEXT NOT NULL DEFAULT (datetime('now')),
          expires_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    } catch (_) {}

    // 2. Add password_hash and password_salt to users
    try {
      await m.addColumn(users, users.passwordHash);
    } catch (_) {}
    try {
      await m.addColumn(users, users.passwordSalt);
    } catch (_) {}

    // 3. Migrate existing plain-text passwords to hashed
    try {
      final allUsers = await (select(users)).get();
      for (final user in allUsers) {
        if (user.passwordHash == null && user.password.isNotEmpty) {
          final salt = const Uuid().v4().substring(0, 16);
          final salted = 'SYS_MARKET_v1:$salt:${user.password}';
          final bytes = utf8.encode(salted);
          final digest = sha256.convert(bytes);
          final hash = digest.toString();
          await (update(users)..where((u) => u.id.equals(user.id))).write(
            UsersCompanion(
              passwordHash: Value(hash),
              passwordSalt: Value(salt),
            ),
          );
        }
      }
    } catch (_) {}

    // 4. Add reconciled column to account_transactions
    try {
      await customStatement('''
        ALTER TABLE account_transactions ADD COLUMN reconciled INTEGER NOT NULL DEFAULT 0
      ''');
    } catch (_) {}

    // 5. Create reconciliation_details table
    try {
      await customStatement('''
        CREATE TABLE IF NOT EXISTS reconciliation_details (
          id TEXT PRIMARY KEY,
          reconciliation_id TEXT NOT NULL REFERENCES reconciliations(id),
          transaction_id TEXT NOT NULL REFERENCES account_transactions(id),
          statement_amount TEXT NOT NULL DEFAULT '0',
          statement_date TEXT NOT NULL,
          reference TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
    } catch (_) {}

    // 6. Add decimal-precision columns alongside RealColumns for financial tables
    // APInvoices
    try {
      await customStatement('ALTER TABLE ap_invoices ADD COLUMN total_amount_text TEXT');
      await customStatement('UPDATE ap_invoices SET total_amount_text = CAST(ROUND(total_amount, 4) AS TEXT)');
    } catch (_) {}

    // StockTakeItems
    try {
      await customStatement('ALTER TABLE stock_take_items ADD COLUMN expected_quantity_text TEXT');
      await customStatement('ALTER TABLE stock_take_items ADD COLUMN actual_quantity_text TEXT');
      await customStatement('UPDATE stock_take_items SET expected_quantity_text = CAST(ROUND(expected_quantity, 4) AS TEXT)');
      await customStatement('UPDATE stock_take_items SET actual_quantity_text = CAST(ROUND(actual_quantity, 4) AS TEXT)');
    } catch (_) {}

    // GoodReceivedNoteItems
    try {
      await customStatement('ALTER TABLE good_received_note_items ADD COLUMN received_quantity_text TEXT');
      await customStatement('ALTER TABLE good_received_note_items ADD COLUMN ordered_quantity_text TEXT');
      await customStatement('UPDATE good_received_note_items SET received_quantity_text = CAST(ROUND(received_quantity, 4) AS TEXT)');
      await customStatement('UPDATE good_received_note_items SET ordered_quantity_text = CAST(ROUND(ordered_quantity, 4) AS TEXT)');
    } catch (_) {}

    // DeliveryNoteItems
    try {
      await customStatement('ALTER TABLE delivery_note_items ADD COLUMN delivered_quantity_text TEXT');
      await customStatement('ALTER TABLE delivery_note_items ADD COLUMN ordered_quantity_text TEXT');
      await customStatement('UPDATE delivery_note_items SET delivered_quantity_text = CAST(ROUND(delivered_quantity, 4) AS TEXT)');
      await customStatement('UPDATE delivery_note_items SET ordered_quantity_text = CAST(ROUND(ordered_quantity, 4) AS TEXT)');
    } catch (_) {}

    // PurchaseOrders
    try {
      await customStatement('ALTER TABLE purchase_orders ADD COLUMN subtotal_text TEXT');
      await customStatement('ALTER TABLE purchase_orders ADD COLUMN tax_amount_text TEXT');
      await customStatement('ALTER TABLE purchase_orders ADD COLUMN total_amount_text TEXT');
      await customStatement('UPDATE purchase_orders SET subtotal_text = CAST(ROUND(subtotal, 4) AS TEXT)');
      await customStatement('UPDATE purchase_orders SET tax_amount_text = CAST(ROUND(tax_amount, 4) AS TEXT)');
      await customStatement('UPDATE purchase_orders SET total_amount_text = CAST(ROUND(total_amount, 4) AS TEXT)');
    } catch (_) {}

    // SalesOrders
    try {
      await customStatement('ALTER TABLE sales_orders ADD COLUMN subtotal_text TEXT');
      await customStatement('ALTER TABLE sales_orders ADD COLUMN tax_amount_text TEXT');
      await customStatement('ALTER TABLE sales_orders ADD COLUMN total_amount_text TEXT');
      await customStatement('UPDATE sales_orders SET subtotal_text = CAST(ROUND(subtotal, 4) AS TEXT)');
      await customStatement('UPDATE sales_orders SET tax_amount_text = CAST(ROUND(tax_amount, 4) AS TEXT)');
      await customStatement('UPDATE sales_orders SET total_amount_text = CAST(ROUND(total_amount, 4) AS TEXT)');
    } catch (_) {}

    // Checks
    try {
      await customStatement('ALTER TABLE checks ADD COLUMN amount_text TEXT');
      await customStatement('UPDATE checks SET amount_text = CAST(ROUND(amount, 4) AS TEXT)');
    } catch (_) {}

    // InvoiceItems
    try {
      await customStatement('ALTER TABLE invoice_items ADD COLUMN quantity_text TEXT');
      await customStatement('ALTER TABLE invoice_items ADD COLUMN unit_price_text TEXT');
      await customStatement('ALTER TABLE invoice_items ADD COLUMN subtotal_text TEXT');
      await customStatement('UPDATE invoice_items SET quantity_text = CAST(ROUND(quantity, 4) AS TEXT)');
      await customStatement('UPDATE invoice_items SET unit_price_text = CAST(ROUND(unit_price, 4) AS TEXT)');
      await customStatement('UPDATE invoice_items SET subtotal_text = CAST(ROUND(subtotal, 4) AS TEXT)');
    } catch (_) {}

    // CreditNoteItems
    try {
      await customStatement('ALTER TABLE credit_note_items ADD COLUMN quantity_text TEXT');
      await customStatement('ALTER TABLE credit_note_items ADD COLUMN unit_price_text TEXT');
      await customStatement('ALTER TABLE credit_note_items ADD COLUMN subtotal_text TEXT');
      await customStatement('UPDATE credit_note_items SET quantity_text = CAST(ROUND(quantity, 4) AS TEXT)');
      await customStatement('UPDATE credit_note_items SET unit_price_text = CAST(ROUND(unit_price, 4) AS TEXT)');
      await customStatement('UPDATE credit_note_items SET subtotal_text = CAST(ROUND(subtotal, 4) AS TEXT)');
    } catch (_) {}
  }

  Future<void> _seedGLAccounts() async {
    final accounts = [
      GLAccountsCompanion.insert(
          code: '1000',
          name: 'الأصول المتداولة',
          type: 'ASSET',
          isHeader: const Value(true)),
      GLAccountsCompanion.insert(code: '1010', name: 'الصندوق', type: 'ASSET'),
      GLAccountsCompanion.insert(code: '1020', name: 'البنك', type: 'ASSET'),
      GLAccountsCompanion.insert(
          code: '1030',
          name: 'العملاء',
          type: 'ASSET',
          analyticType: const Value('CLIENT')),
      GLAccountsCompanion.insert(
          code: '1200',
          name: 'مخزون البضاعة',
          type: 'ASSET',
          isHeader: const Value(true)),
      GLAccountsCompanion.insert(
          code: '1210', name: 'مخزون البضاعة', type: 'ASSET'),
      GLAccountsCompanion.insert(
          code: '2000',
          name: 'الخصوم المتداولة',
          type: 'LIABILITY',
          isHeader: const Value(true)),
      GLAccountsCompanion.insert(
          code: '2010',
          name: 'الموردون',
          type: 'LIABILITY',
          analyticType: const Value('SUPPLIER')),
      GLAccountsCompanion.insert(
          code: '2020', name: 'ضريبة القيمة المضافة', type: 'LIABILITY'),
      GLAccountsCompanion.insert(
          code: '3000',
          name: 'حقوق الملكية',
          type: 'EQUITY',
          isHeader: const Value(true)),
      GLAccountsCompanion.insert(
          code: '3010', name: 'رأس المال', type: 'EQUITY'),
      GLAccountsCompanion.insert(
          code: '3020', name: 'الأرباح المحتجزة', type: 'EQUITY'),
      GLAccountsCompanion.insert(
          code: '4000',
          name: 'الإيرادات',
          type: 'REVENUE',
          isHeader: const Value(true)),
      GLAccountsCompanion.insert(
          code: '4010', name: 'مبيعات البضاعة', type: 'REVENUE'),
      GLAccountsCompanion.insert(
          code: '4020', name: 'مردودات المبيعات', type: 'REVENUE'),
      GLAccountsCompanion.insert(
          code: '5000',
          name: 'تكلفة البضاعة المباعة',
          type: 'EXPENSE',
          isHeader: const Value(true)),
      GLAccountsCompanion.insert(
          code: '5010', name: 'تكلفة البضاعة المباعة', type: 'EXPENSE'),
      GLAccountsCompanion.insert(
          code: '5020', name: 'فرق صندوق', type: 'EXPENSE'),
      GLAccountsCompanion.insert(
          code: '6000',
          name: 'المصروفات',
          type: 'EXPENSE',
          isHeader: const Value(true)),
      GLAccountsCompanion.insert(
          code: '6010', name: 'مصروفات التشغيل', type: 'EXPENSE'),
    ];

    for (final acc in accounts) {
      final existing = await (select(gLAccounts)
            ..where((a) => a.code.equals(acc.code.value)))
          .getSingleOrNull();
      if (existing == null) {
        await into(gLAccounts).insert(acc);
      }
    }
  }

  Future<void> _seedPostingProfiles() async {
    final countExp = postingProfiles.id.count();
    final countQuery = selectOnly(postingProfiles)..addColumns([countExp]);
    final profilesCount =
        await countQuery.map((row) => row.read(countExp)).getSingle();
    if ((profilesCount ?? 0) > 0) return;

    final gLAccountsList = await select(gLAccounts).get();
    Map<String, String> accountIdByCode = {
      for (var acc in gLAccountsList) acc.code: acc.id
    };

    if (accountIdByCode['1010'] == null ||
        accountIdByCode['4010'] == null ||
        accountIdByCode['5010'] == null) {
      return;
    }

    final profiles = [
      PostingProfilesCompanion.insert(
        operationType: 'SALE',
        accountType: 'CASH',
        accountId: Value(accountIdByCode['1010']),
        isActive: const Value(true),
        sequence: const Value(1),
        side: 'DEBIT',
      ),
      PostingProfilesCompanion.insert(
        operationType: 'SALE',
        accountType: 'REVENUE',
        accountId: Value(accountIdByCode['4010']),
        isActive: const Value(true),
        sequence: const Value(2),
        side: 'CREDIT',
      ),
      PostingProfilesCompanion.insert(
        operationType: 'SALE',
        accountType: 'COGS',
        accountId: Value(accountIdByCode['5010']),
        isActive: const Value(true),
        sequence: const Value(3),
        side: 'DEBIT',
      ),
      PostingProfilesCompanion.insert(
        operationType: 'SALE',
        accountType: 'INVENTORY',
        accountId: Value(accountIdByCode['1210']),
        isActive: const Value(true),
        sequence: const Value(4),
        side: 'CREDIT',
      ),
      PostingProfilesCompanion.insert(
        operationType: 'PURCHASE',
        accountType: 'INVENTORY',
        accountId: Value(accountIdByCode['1210']),
        isActive: const Value(true),
        sequence: const Value(1),
        side: 'DEBIT',
      ),
      PostingProfilesCompanion.insert(
        operationType: 'PURCHASE',
        accountType: 'CASH',
        accountId: Value(accountIdByCode['1010']),
        isActive: const Value(true),
        sequence: const Value(2),
        side: 'CREDIT',
      ),
      PostingProfilesCompanion.insert(
        operationType: 'PURCHASE',
        accountType: 'PAYABLE',
        accountId: Value(accountIdByCode['2010']),
        isActive: const Value(true),
        sequence: const Value(3),
        side: 'CREDIT',
      ),
    ];

    await batch((b) {
      for (var profile in profiles) {
        b.insert(postingProfiles, profile);
      }
    });
  }

  Future<void> ensureInitialized() async {
    // Trigger connection, migrations, and idempotent core reference seeding.
    await (selectOnly(branches)..limit(1)).get();
    await ensureCoreReferenceData();
  }

  // DAO getters
  @override
  AccountingDao get accountingDao => AccountingDao(this);
  @override
  CustomersDao get customersDao => CustomersDao(this);
  @override
  ProductsDao get productsDao => ProductsDao(this);
  @override
  SalesDao get salesDao => SalesDao(this);
  @override
  PurchasesDao get purchasesDao => PurchasesDao(this);
  @override
  SuppliersDao get suppliersDao => SuppliersDao(this);
  @override
  UsersDao get usersDao => UsersDao(this);
  @override
  WarehousesDao get warehousesDao => WarehousesDao(this);
  @override
  GlobalUnitsDao get globalUnitsDao => GlobalUnitsDao(this);
  @override
  ProductUnitsDao get productUnitsDao => ProductUnitsDao(this);
  @override
  BomDao get bomDao => BomDao(this);
  @override
  AuditDao get auditDao => AuditDao(this);
  @override
  StockMovementDao get stockMovementDao => StockMovementDao(this);
  @override
  CashboxDao get cashboxDao => CashboxDao(this);
  @override
  TransfersDao get transfersDao => TransfersDao(this);
}

/// Reads the first 16 bytes of [file] to detect the standard SQLite header
/// magic ("SQLite format 3\0"). Returns true if the file is a plain (unencrypted)
/// SQLite database — meaning SQLCipher encryption has never been applied.
Future<bool> _isPlainSqliteDatabase(File file) async {
  try {
    final raf = await file.open(mode: FileMode.read);
    try {
      final bytes = await raf.read(16);
      if (bytes.length < 16) return false;
      return bytes[0] == 0x53 && bytes[1] == 0x51 && bytes[2] == 0x4c &&
             bytes[3] == 0x69 && bytes[4] == 0x74 && bytes[5] == 0x65 &&
             bytes[6] == 0x20 && bytes[7] == 0x66 && bytes[8] == 0x6f &&
             bytes[9] == 0x72 && bytes[10] == 0x6d && bytes[11] == 0x61 &&
             bytes[12] == 0x74 && bytes[13] == 0x20 && bytes[14] == 0x33 &&
             bytes[15] == 0x00;
    } finally {
      await raf.close();
    }
  } catch (_) {
    return false;
  }
}

Future<void> _backupAndDelete(File file, String suffix) async {
  final backupPath =
      "${file.path}.${suffix}_${DateTime.now().millisecondsSinceEpoch}";
  await file.copy(backupPath);
  debugPrint("DB: Corrupted file backed up to $backupPath");
  await file.delete();
}

/// Converts an unencrypted SQLite database at [file] to the SQLCipher format
/// using [key]. The process:
/// 1. Opens the plain database (SQLCipher in standard mode, no PRAGMA key).
/// 2. ATTACHes a temporary encrypted database with the target key.
/// 3. Uses sqlcipher_export() to copy all schema + data.
/// 4. Verifies integrity of the new encrypted file.
/// 5. Backs up the original, then replaces it with the encrypted version.
///
/// WARNING: This operation is synchronous and blocks the calling isolate. For
/// large databases the conversion may take noticeable time.
Future<File> _convertToEncrypted(File file, String key) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final tempPath = '${file.path}.encrypted_$timestamp';
  final tempFile = File(tempPath);

  debugPrint("DB ENCRYPT: Converting unencrypted SQLite -> SQLCipher...");

  final escapedKey = key.replaceAll("'", "''");
  final escapedTempPath = tempPath.replaceAll("'", "''");

  try {
    final db = sqlite.sqlite3.open(file.path);
    try {
      db.execute("ATTACH DATABASE '$escapedTempPath' AS encrypted KEY '$escapedKey'");

      db.execute("SELECT sqlcipher_export('encrypted')");
      debugPrint("DB ENCRYPT: sqlcipher_export completed.");
      db.execute("DETACH DATABASE encrypted");
    } finally {
      db.dispose();
    }

    // Verify the newly created encrypted database
    final verifyDb = sqlite.sqlite3.open(tempPath);
    try {
      verifyDb.execute("PRAGMA key = '$escapedKey'");
      final result = verifyDb.select("PRAGMA integrity_check;");
      final status = result.first.values.first as String;
      if (status != 'ok') {
        throw Exception("Encrypted DB integrity check failed: $status");
      }
      debugPrint("DB ENCRYPT: Integrity check passed: $status");
    } finally {
      verifyDb.dispose();
    }

    // Keep a safe backup of the original unencrypted file
    final backupPath = '${file.path}.unencrypted_backup_$timestamp';
    await file.copy(backupPath);
    debugPrint("DB ENCRYPT: Original unencrypted DB backed up to: $backupPath");

    // Atomically replace the original with the encrypted version
    await file.delete();
    await tempFile.rename(file.path);
    debugPrint("DB ENCRYPT: Conversion complete — encrypted DB is live.");

    return file;
  } catch (e) {
    debugPrint("DB ENCRYPT: Conversion failed: $e");
    // Clean up the temporary file if it was created
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    rethrow;
  }
}

LazyDatabase _openConnection() {
  debugPrint("DB: _openConnection started");
  return LazyDatabase(() async {
    try {
      debugPrint("DB: Getting application documents directory...");
      final dbFolder = await getApplicationDocumentsDirectory();
      debugPrint("DB: Documents directory: ${dbFolder.path}");

      final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
      debugPrint("DB: Database file path: ${file.path}");
      
      if (await file.exists()) {
        final size = await file.length();
        debugPrint("DB: Existing file size: $size bytes");
        if (size == 0) {
          debugPrint("DB: File is empty (0 bytes). Deleting so SQLite can create a fresh valid database.");
          await file.delete();
        } else if (size < 100) {
          debugPrint("DB: File too small ($size bytes) for valid SQLite. Backing up and recreating...");
          await _backupAndDelete(file, 'corrupted');
        } else if (!await _isPlainSqliteDatabase(file)) {
          debugPrint("DB: File does not have a valid SQLite header. Backing up and recreating...");
          await _backupAndDelete(file, 'invalid');
        }
      } else {
        debugPrint("DB: File does not exist, it will be created.");
      }

      // PRE-FLIGHT: Detect unencrypted SQLite databases and convert to SQLCipher.
      // Without this, Drift's beforeOpen would send PRAGMA key on a plain file,
      // making SQLCipher attempt to decrypt plain pages → error 26.
      // If conversion fails we fall back to the beforeOpen error 26 recovery.
      if (!SecurityService.useFakeKeyForTesting && await file.exists()) {
        final size = await file.length();
        if (size > 0 && await _isPlainSqliteDatabase(file)) {
          debugPrint("DB: Plain (unencrypted) SQLite detected at ${file.path}");
          debugPrint("DB: Starting automatic conversion to SQLCipher...");
          final key = await SecurityService.getDatabaseKey();
          try {
            await _convertToEncrypted(file, key);
            debugPrint("DB: Pre-flight conversion complete.");
          } catch (conversionError) {
            debugPrint("DB: Pre-flight conversion failed: $conversionError");
            debugPrint("DB: Falling back to beforeOpen — error 26 recovery will handle this.");
          }
        }
      }

      final cachebase = (await getTemporaryDirectory()).path;
      sqlite.sqlite3.tempDirectory = cachebase;

      debugPrint("DB: Creating NativeDatabase with isolateSetup...");
      final db = NativeDatabase.createInBackground(
        file,
        logStatements: kDebugMode,
        isolateSetup: () async {
          applyNativeSqlOverride();
        },
      );
      debugPrint("DB: NativeDatabase created successfully");
      return db;
    } catch (e, stack) {
      debugPrint("DB ERROR in _openConnection: $e");
      debugPrintStack(stackTrace: stack);
      
      // If we are here, something went wrong during opening
      if (e.toString().contains('code 26')) {
         debugPrint("DB: Cannot decrypt database with current key (error 26).");
         debugPrint("DB WARNING: DATA LOSS POSSIBLE. The database 'app_db.sqlite'");
         debugPrint("DB WARNING: could not be decrypted. This can happen if:");
         debugPrint("DB WARNING:   1. FlutterSecureStorage lost its data (app reinstall / data clear)");
         debugPrint("DB WARNING:      while the .sqlite file survived with an old key.");
         debugPrint("DB WARNING:   2. The database file is genuinely corrupted.");
         debugPrint("DB WARNING: A backup of the existing file will be saved before recreating.");
         debugPrint("DB: Attempting emergency recovery — backing up and recreating...");
         try {
           final dbFolder = await getApplicationDocumentsDirectory();
           final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
           if (await file.exists()) {
              final backupPath = "${file.path}.corrupted_${DateTime.now().millisecondsSinceEpoch}";
              await file.copy(backupPath);
              debugPrint("DB: Corrupted file backed up to $backupPath");
              await file.delete();
              debugPrint("DB: Corrupted file deleted. Retrying initialization...");
              return NativeDatabase.createInBackground(
                file,
                logStatements: kDebugMode,
                isolateSetup: () async {
                  applyNativeSqlOverride();
                },
              ); 
           }
         } catch (recoveryError) {
           debugPrint("DB: Recovery failed: $recoveryError");
         }
      }
      
      rethrow;
    }
  });
}
