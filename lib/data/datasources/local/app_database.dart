import 'dart:io';
// ignore_for_file: deprecated_member_use
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supermarket/core/services/permission_service.dart';
import 'package:supermarket/native_sql_override.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:decimal/decimal.dart';

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
export 'package:decimal/decimal.dart';
export 'converters/decimal_converter.dart';

// Table definitions provided as part files
part 'tables/app_config_table.dart';
part 'tables/payroll_tables.dart';
part 'tables/fixed_assets_tables.dart';
part 'tables/advanced_accounting_tables.dart';
part 'tables/app_settings_table.dart';
part 'tables/audit_logs_table.dart';
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
  TextColumn get buyPrice => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get sellPrice => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get wholesalePrice => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get stock => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get maxStock => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.fromInt(1000).toString()))();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get valuationMethod =>
      text().withDefault(const Constant('FIFO'))(); // FIFO, AVCO
  BoolColumn get allowFreeQty => boolean().withDefault(const Constant(false))();
  BoolColumn get isService => boolean().withDefault(const Constant(false))();
  TextColumn get alertLimit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.fromInt(10).toString()))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get taxRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // Variant support
  TextColumn get parentProductId => text().nullable().references(
        Products,
        #id,
      )(); // Null for main items; points to parent for variants
  TextColumn get attributes =>
      text().nullable()(); // JSON: {"color":"Red","size":"XL"}
  TextColumn get additionalCost => text()
      .map(const DecimalConverter())
      .nullable()(); // Extra cost for variant over base product
  TextColumn get imagePath => text().nullable()(); // Local image file path
}

class ProductUnits extends Table with SyncableTable {
  // Multi-unit support for products (and variants)
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitName => text()(); // e.g., carton, box, kilo
  TextColumn get barcode =>
      text().unique().nullable()(); // Barcode for this unit
  TextColumn get unitFactor => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))(); // How many base units
  TextColumn get buyPrice => text()
      .map(const DecimalConverter())
      .nullable()(); // Unit-specific buy price
  TextColumn get sellPrice => text()
      .map(const DecimalConverter())
      .nullable()(); // Unit-specific sell price
  TextColumn get wholesalePrice => text()
      .map(const DecimalConverter())
      .nullable()(); // Wholesale price for this unit
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
  TextColumn get creditLimit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get balance => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get accountId =>
      text().nullable().references(GLAccounts, #id)(); // New: Linked to GL
  TextColumn get currencyId => text().nullable().references(Currencies, #id)();
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
  BoolColumn get isQuickCustomer =>
      boolean().withDefault(const Constant(false))(); // Quick customer flag
  BoolColumn get createdFromPOS =>
      boolean().withDefault(const Constant(false))(); // Created from POS
  TextColumn get discountRate =>
      text().map(const DecimalConverter()).withDefault(
          Constant(Decimal.zero.toString()))(); // Customer-specific discount
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
  TextColumn get balance => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get accountId =>
      text().nullable().references(GLAccounts, #id)(); // New: Linked to GL
  TextColumn get creditLimit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get currencyId => text().nullable().references(Currencies, #id)();
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
}

class GlobalUnits extends Table with SyncableTable {
  TextColumn get name => text().unique()();
  TextColumn get symbol => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();
}

class Sales extends Table with SyncableTable {
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get total => text().map(const DecimalConverter())();
  TextColumn get discount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get tax => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  IntColumn get paymentMethod =>
      integer().map(const PaymentMethodConverter())();
  BoolColumn get isCredit => boolean().withDefault(const Constant(false))();
  IntColumn get status => integer()
      .map(const DocumentStatusConverter())
      .withDefault(const Constant(0))();
  TextColumn get saleType =>
      text().withDefault(const Constant('retail'))(); // retail / wholesale
  TextColumn get currencyId => text().nullable()();
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
  TextColumn get shippingCost => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get otherExpenses => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get unitFactor => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
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
  TextColumn get cost => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))(); // ADDED COST
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
  TextColumn get tax => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get discount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get landedCosts => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get shippingCost => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get otherExpenses => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
  TextColumn get notes => text().nullable()();
  TextColumn get referenceDocument => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
}

class PurchaseItems extends Table with SyncableTable {
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitId =>
      text().nullable()(); // New: Unit ID (e.g., carton, kilo)
  TextColumn get unitFactor => text().map(const DecimalConverter()).withDefault(
      Constant(Decimal.one.toString()))(); // New: Conversion to base unit
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get quantityInBaseUnit => text()
      .map(const DecimalConverter())
      .nullable()(); // New: Calculated base quantity
  TextColumn get unitPrice =>
      text().map(const DecimalConverter())(); // New: Price per selected unit
  TextColumn get price => text()
      .map(const DecimalConverter())(); // Total price (kept for compatibility)
  TextColumn get discount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))(); // New: Item discount
  TextColumn get discountPercent =>
      text().map(const DecimalConverter()).withDefault(
          Constant(Decimal.zero.toString()))(); // New: Discount percentage
  TextColumn get tax => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))(); // New: Tax amount
  TextColumn get taxPercent => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))(); // New: Tax percentage
  TextColumn get landedCostShare =>
      text().map(const DecimalConverter()).withDefault(
          Constant(Decimal.zero.toString()))(); // New: Share of landed costs
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
  TextColumn get quantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get initialQuantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get costPrice => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}

/// Item variants (e.g., color, size) for products with multiple attributes
class ItemVariants extends Table with SyncableTable {
  @override
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class SalesReturns extends Table with SyncableTable {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get amountReturned => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get reason => text().nullable()();
}

class SalesReturnItems extends Table with SyncableTable {
  TextColumn get salesReturnId => text().references(SalesReturns, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get price => text().map(const DecimalConverter())();
  TextColumn get unitFactor => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
}

class PurchaseReturns extends Table with SyncableTable {
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get amountReturned => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get remainingAmount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))(); // Unapplied amount
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
  TextColumn get amount =>
      text().map(const DecimalConverter())(); // Amount applied to this purchase
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
  TextColumn get balance => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}

class CostCenters extends Table with SyncableTable {
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable().references(CostCenters, #id)();
  TextColumn get type => text().withDefault(
      const Constant('department'))(); // department, project, branch
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
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
}

class GLLines extends Table with SyncableTable {
  @override
  String get tableName => 'gl_lines';

  TextColumn get entryId => text().references(GLEntries, #id)();
  TextColumn get accountId => text().references(GLAccounts, #id)();
  TextColumn get costCenterId =>
      text().nullable().references(CostCenters, #id)();
  TextColumn get debit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get credit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get currencyId => text().nullable().references(Currencies, #id)();
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
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
  TextColumn get systemStock => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get actualStock => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get difference => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}

class Shifts extends Table with SyncableTable {
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get startTime => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get openingCash => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get closingCash =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get expectedCash =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isOpen => boolean().withDefault(const Constant(true))();
}

class Reconciliations extends Table with SyncableTable {
  TextColumn get accountId => text().references(GLAccounts, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get bookBalance => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get actualBalance => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get difference => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get quantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}

class Employees extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get employeeCode => text().unique()();
  TextColumn get jobTitle => text().nullable()();
  TextColumn get role =>
      text().withDefault(const Constant('USER'))(); // ADMIN or USER
  TextColumn get basicSalary => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get basicSalary => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get allowances => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get deductions => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get netSalary => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get amount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get amount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();

  TextColumn get commission => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get price => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get minQuantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}

class Promotions extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get type =>
      text()(); // PERCENTAGE_DISCOUNT, FIXED_DISCOUNT, BOGO (Buy One Get One)
  TextColumn get value => text().map(const DecimalConverter()).withDefault(
      Constant(Decimal.zero.toString()))(); // Discount amount or percentage
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get minPurchaseAmount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}

class PriceHistory extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get oldPrice => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get newPrice => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get type => text()(); // PURCHASE / SALE
}

class Currencies extends Table with SyncableTable {
  TextColumn get code => text().unique()(); // e.g., USD, YER, SAR
  TextColumn get name => text()();
  TextColumn get fractionalUnit => text().nullable()(); // فكة العملة
  IntColumn get decimalPlaces =>
      integer().withDefault(const Constant(2))(); // عدد الكسور
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
}

class ExchangeRates extends Table {
  @ReferenceName('fromCurrencyExchangeRates')
  TextColumn get fromCurrencyCode => text().references(Currencies, #code)();
  @ReferenceName('toCurrencyExchangeRates')
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
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.one
          .toString()))(); // How many of this unit equal the base unit
  BoolColumn get isBaseUnit => boolean().withDefault(const Constant(false))();
  TextColumn get buyPrice => text()
      .map(const DecimalConverter())
      .nullable()(); // Unit-specific buy price
  TextColumn get sellPrice => text()
      .map(const DecimalConverter())
      .nullable()(); // Unit-specific sell price
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
  TextColumn get taxAmount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get paidAmount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get taxAmount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get paidAmount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get status => text()
      .withDefault(const Constant('DRAFT'))(); // DRAFT, POSTED, PAID, PARTIAL
  TextColumn get notes => text().nullable()();
  TextColumn get accountId => text().nullable().references(GLAccounts, #id)();
}

class InventoryTransactions extends Table with SyncableTable {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
  TextColumn get quantity => text().map(const DecimalConverter()).withDefault(
      Constant(Decimal.zero.toString()))(); // Positive for in, negative for out
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
  TextColumn get debit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get credit => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get expectedQty => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get actualQty => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get variance => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get quantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get quantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get batchId => text().nullable().references(ProductBatches, #id)();
}

class Checks extends Table with SyncableTable {
  TextColumn get checkNumber => text()();
  TextColumn get bankName => text()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get amount => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get exchangeRate => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.one.toString()))();
}

class BillOfMaterials extends Table with SyncableTable {
  @ReferenceName('finishedProduct')
  TextColumn get finishedProductId => text().references(Products, #id)();
  @ReferenceName('componentProduct')
  TextColumn get componentProductId => text().references(Products, #id)();
  TextColumn get quantity =>
      text().map(const DecimalConverter()).withDefault(Constant(Decimal.zero
          .toString()))(); // الكمية المطلوبة من المادة الخام لإنتاج وحدة واحدة
}

class ProductionOrders extends Table with SyncableTable {
  TextColumn get finishedProductId => text().references(Products, #id)();
  TextColumn get plannedQuantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get actualQuantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant(
      'PLANNED'))(); // PLANNED, IN_PROGRESS, COMPLETED, CANCELLED
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  TextColumn get note => text().nullable()();
}

class ProductionOrderItems extends Table with SyncableTable {
  TextColumn get productionOrderId =>
      text().references(ProductionOrders, #id)();
  TextColumn get componentProductId => text().references(Products, #id)();
  TextColumn get plannedQuantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get actualQuantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get unitCost => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
}

class PurchaseOrders extends Table with SyncableTable {
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get total => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get quantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get price => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get unitId => text().nullable()();
}

class SalesOrders extends Table with SyncableTable {
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get total => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
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
  TextColumn get quantity => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get price => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  TextColumn get unitId => text().nullable()();
}

class CustomerPaymentLinks extends Table with SyncableTable {
  // Links customer payments to sales for invoice-wise tracking
  TextColumn get paymentId => text().references(CustomerPayments, #id)();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get amount => text().map(const DecimalConverter()).withDefault(
      Constant(Decimal.zero.toString()))(); // Amount applied to this sale
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
    ExchangeRates,
    AppConfigTable,
    AppSettings,
    AuditLogsTable,
    AccAssetCategories,
    FixedAssets,
    AccAssetDepreciationLogs,
    AccAssetDisposals,
    AccBudgets,
    AccBankStatements,
    AccBankStatementLines,
    AccAuditLogs,
    HREmployees,
    HRPayrollRuns,
    HRPayrollDetails,
    HRAdditionalDeductions,
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
  int get schemaVersion => 43;

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
          if (from < 42) {
            await _migrateToV42(m);
          }
          if (from < 43) {
            // Version 43: Add imagePath column to Products for product images
            try {
              await m.addColumn(products, products.imagePath);
            } catch (_) {}
          }
        },
        beforeOpen: (details) async {
          debugPrint(
              "DB: beforeOpen started. Details: ${details.wasCreated ? 'Created' : 'Opened'}");

          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA synchronous = NORMAL;');
          await ensurePerformanceIndexes();
          // Existing databases might predate critical seed data. Keep this
          // idempotent so lookups (currencies/branches/GL headers) are never empty.
          await ensureCoreReferenceData();

          // Log schema version and table list for verification
          final versionResult = await customSelect("PRAGMA user_version").get();
          debugPrint(
              "DB: Schema version: ${versionResult.first.data.values.first}");
          final tables = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
          ).get();
          debugPrint("DB: Database has ${tables.length} tables:");
          for (final t in tables) {
            debugPrint("DB:   - ${t.data['name']}");
          }
        },
      );

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
    'CREATE INDEX IF NOT EXISTS sales_orders_customer_id_idx ON sales_orders (customer_id)',
    'CREATE INDEX IF NOT EXISTS sales_orders_status_idx ON sales_orders (status)',
    'CREATE INDEX IF NOT EXISTS sales_orders_created_at_idx ON sales_orders (created_at)',
    'CREATE INDEX IF NOT EXISTS sales_order_items_order_id_idx ON sales_order_items (order_id)',
    'CREATE INDEX IF NOT EXISTS sales_order_items_product_id_idx ON sales_order_items (product_id)',
    'CREATE INDEX IF NOT EXISTS purchase_orders_status_idx ON purchase_orders (status)',
    'CREATE INDEX IF NOT EXISTS purchase_orders_created_at_idx ON purchase_orders (created_at)',
    'CREATE INDEX IF NOT EXISTS purchase_order_items_order_id_idx ON purchase_order_items (order_id)',
    'CREATE INDEX IF NOT EXISTS inventory_transactions_product_id_idx ON inventory_transactions (product_id)',
    'CREATE INDEX IF NOT EXISTS inventory_transactions_warehouse_id_idx ON inventory_transactions (warehouse_id)',
    'CREATE INDEX IF NOT EXISTS inventory_transactions_type_idx ON inventory_transactions (type)',
    'CREATE INDEX IF NOT EXISTS currencies_code_idx ON currencies (code)',
    'CREATE INDEX IF NOT EXISTS currencies_is_base_idx ON currencies (is_base)',
    'CREATE INDEX IF NOT EXISTS shifts_user_id_idx ON shifts (user_id)',
    'CREATE INDEX IF NOT EXISTS shifts_is_open_idx ON shifts (is_open)',
    'CREATE INDEX IF NOT EXISTS cashbox_transactions_type_idx ON cashbox_transactions (type)',
    'CREATE INDEX IF NOT EXISTS customers_name_idx ON customers (name)',
    'CREATE INDEX IF NOT EXISTS suppliers_name_idx ON suppliers (name)',
    'CREATE INDEX IF NOT EXISTS permissions_code_idx ON permissions (code)',
    'CREATE INDEX IF NOT EXISTS role_permissions_role_idx ON role_permissions (role)',
    'CREATE INDEX IF NOT EXISTS role_permissions_permission_code_idx ON role_permissions (permission_code)',
  ];

  Future<void> ensurePerformanceIndexes() async {
    for (final statement in _performanceIndexStatements) {
      await customStatement(statement);
    }
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

  // --- Missing Methods Recovery ---

  Future<void> seedData() async {
    await ensureCoreReferenceData();
    await seedSecurityData();
  }

  Future<void> ensureCoreReferenceData() async {
    await ensureDefaultBranch();
    await ensureDefaultCurrencies();
  }

  Future<void> seedSecurityData() async {
    final permissionService = PermissionService(this);
    await permissionService.seedPermissions();

    final roles = ['admin', 'manager', 'cashier'];
    for (final role in roles) {
      final existingCount = await (select(rolePermissions)
            ..where((rp) => rp.role.equals(role)))
          .get()
          .then((list) => list.length);
      if (existingCount > 0) continue;

      final permissions = PermissionService.allPermissions.keys.toList();
      for (final pCode in permissions) {
        if (role == 'admin' ||
            (role == 'manager' && pCode != PermissionCode.manageUsers) ||
            (role == 'cashier' && pCode == PermissionCode.postSale)) {
          await into(rolePermissions).insert(RolePermissionsCompanion.insert(
            role: role,
            permissionCode: pCode,
          ));
        }
      }
    }
  }

  Future<String> ensureDefaultBranch() async {
    try {
      final existing = await select(branches).get();
      if (existing.isEmpty) {
        final row =
            await into(branches).insertReturning(BranchesCompanion.insert(
          name: 'الفرع الرئيسي',
          code: 'MAIN',
          isActive: const Value(true),
        ));
        return row.id;
      }
      return existing.first.id;
    } catch (e) {
      debugPrint('Error seeding default branch: $e');
      return '';
    }
  }

  Future<void> ensureDefaultCurrencies() async {
    try {
      final existing = await select(currencies).get();
      if (existing.isEmpty) {
        await into(currencies).insert(CurrenciesCompanion.insert(
          id: const Value('SAR'),
          code: 'SAR',
          name: 'ريال سعودي',
          exchangeRate: Value(Decimal.one),
          isBase: const Value(true),
        ));
      }
    } catch (e) {
      debugPrint('Error seeding default currencies: $e');
    }
  }

  Future<void> _migrateToV40(Migrator m) async {
    // Migration logic from Section C of implementation guide
    try {
      await m.createTable(currencies);
      await m.createTable(exchangeRates);

      // Seed initial currency if table was just created
      await ensureDefaultCurrencies();
    } catch (e) {
      debugPrint('Migration to V40 failed: $e');
    }
  }

  Future<void> _migrateToV41(Migrator m) async {
    try {
      await m.createTable(appConfigTable);
    } catch (e) {
      debugPrint('Migration to V41 failed: $e');
    }
  }

  Future<void> _migrateToV42(Migrator m) async {
    try {
      // Re-create tables with new types (Decimal instead of Real)
      // This is a destructive migration for early stage dev.
      // In production, we'd use temp tables and copy data.
      await m.deleteTable('stock_take_items');
      await m.createTable(stockTakeItems);

      await m.deleteTable('good_received_note_items');
      await m.createTable(goodReceivedNoteItems);

      await m.deleteTable('delivery_note_items');
      await m.createTable(deliveryNoteItems);

      await m.deleteTable('checks');
      await m.createTable(checks);

      await m.deleteTable('purchase_orders');
      await m.createTable(purchaseOrders);

      await m.deleteTable('purchase_order_items');
      await m.createTable(purchaseOrderItems);

      await m.deleteTable('sales_orders');
      await m.createTable(salesOrders);

      await m.deleteTable('sales_order_items');
      await m.createTable(salesOrderItems);

      await m.deleteTable('customer_payment_links');
      await m.createTable(customerPaymentLinks);

      // Currency Unification: Copy AccCurrencies to Currencies
      final accCurrenciesExists = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='acc_currencies'",
      ).getSingleOrNull();

      if (accCurrenciesExists != null) {
        await customStatement(
            "INSERT OR IGNORE INTO currencies (id, code, name, exchange_rate, is_base) "
            "SELECT CAST(id AS TEXT), code, name, exchange_rate, is_base FROM acc_currencies");

        await m.deleteTable('acc_currencies');
        await m.deleteTable('acc_exchange_rates');
      }

      debugPrint(
          'Migration to V42 (Decimal & Currency Unification) completed.');
    } catch (e) {
      debugPrint('Migration to V42 failed: $e');
    }
  }

  Future<double> calculateTotalInventoryValue() async {
    try {
      final rows = await select(productBatches).get();
      Decimal total = Decimal.zero;
      for (final row in rows) {
        total += row.quantity * row.costPrice;
      }
      return total.toDouble();
    } catch (e) {
      debugPrint('Error calculating inventory value: $e');
      return 0.0;
    }
  }

  Stream<List<Product>> watchLowStockProducts() {
    return productsDao.watchLowStockProducts();
  }

  Future<int> getUnsyncedCount() async {
    try {
      // Assuming 1 is pending status
      final countExp = syncQueue.id.count();
      final query = selectOnly(syncQueue)
        ..addColumns([countExp])
        ..where(syncQueue.status.equals(1));
      final row = await query.getSingle();
      return row.read(countExp) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> runHrBackfill({
    bool dryRun = false,
    bool verbose = false,
    bool rollback = false,
    int batchSize = 50,
  }) async {
    debugPrint('HR backfill triggered: dryRun=$dryRun, rollback=$rollback');
    // Implement backfill logic if needed
  }
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
      return bytes[0] == 0x53 &&
          bytes[1] == 0x51 &&
          bytes[2] == 0x4c &&
          bytes[3] == 0x69 &&
          bytes[4] == 0x74 &&
          bytes[5] == 0x65 &&
          bytes[6] == 0x20 &&
          bytes[7] == 0x66 &&
          bytes[8] == 0x6f &&
          bytes[9] == 0x72 &&
          bytes[10] == 0x6d &&
          bytes[11] == 0x61 &&
          bytes[12] == 0x74 &&
          bytes[13] == 0x20 &&
          bytes[14] == 0x33 &&
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
/// using [key].
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
      db.execute(
          "ATTACH DATABASE '$escapedTempPath' AS encrypted KEY '$escapedKey'");
      db.execute("SELECT sqlcipher_export('encrypted')");
      db.execute("DETACH DATABASE encrypted");
    } finally {
      db.dispose();
    }

    final verifyDb = sqlite.sqlite3.open(tempPath);
    try {
      verifyDb.execute("PRAGMA key = '$escapedKey'");
      final result = verifyDb.select("PRAGMA integrity_check;");
      if (result.first.values.first != 'ok') {
        throw Exception("Encrypted DB integrity check failed");
      }
    } finally {
      verifyDb.dispose();
    }

    final backupPath = '${file.path}.unencrypted_backup_$timestamp';
    await file.copy(backupPath);
    await file.delete();
    await tempFile.rename(file.path);

    return file;
  } catch (e) {
    debugPrint("DB ENCRYPT: Conversion failed: $e");
    if (await tempFile.exists()) await tempFile.delete();
    rethrow;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return await _connectWithRecovery();
  });
}

Future<QueryExecutor> _connectWithRecovery({bool isRetry = false}) async {
  try {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_db.sqlite'));

    if (await file.exists()) {
      final size = await file.length();
      if (size == 0) {
        await file.delete();
      } else if (size < 100) {
        await _backupAndDelete(file, 'corrupted');
      }
    }

    String? encryptionKey;
    if (!SecurityService.useFakeKeyForTesting) {
      encryptionKey = await SecurityService.getDatabaseKey();
    }

    if (encryptionKey != null && await file.exists()) {
      if (await _isPlainSqliteDatabase(file)) {
        try {
          await _convertToEncrypted(file, encryptionKey);
        } catch (_) {}
      }
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite.sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(
      file,
      logStatements: kDebugMode,
      setup: (rawDb) {
        if (encryptionKey != null) {
          final escapedKey = encryptionKey.replaceAll("'", "''");
          rawDb.execute("PRAGMA key = '$escapedKey'");
          rawDb.execute('PRAGMA cipher_page_size = 4096');
          rawDb.execute('PRAGMA kdf_iter = 64000');
          try {
            try {
              final cv = rawDb.select('PRAGMA cipher_version;');
              final cvValue = cv.isNotEmpty ? cv.first.values.first : null;
              if (cvValue == null || (cvValue is String && cvValue.isEmpty)) {
                throw Exception('NO_SQLCIPHER');
              }
            } catch (e) {
              if (e.toString().contains('NO_SQLCIPHER')) rethrow;
              throw Exception('NO_SQLCIPHER');
            }

            rawDb.execute('SELECT count(*) FROM sqlite_master;');
          } catch (e) {
            final s = e.toString();
            if (s.contains('NO_SQLCIPHER')) {
              throw Exception('NO_SQLCIPHER');
            }
            if (s.contains('code 26') || s.contains('file is not a database')) {
              throw Exception('ENCRYPTION_FAILURE');
            }
            rethrow;
          }
        }
      },
      isolateSetup: () async {
        applyNativeSqlOverride();
      },
    );
  } catch (e) {
    if (!isRetry &&
        (e.toString().contains('code 26') ||
            e.toString().contains('ENCRYPTION_FAILURE'))) {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
      if (await file.exists()) {
        final backupPath =
            "${file.path}.FAILED_DECRYPT_${DateTime.now().millisecondsSinceEpoch}";
        await file.copy(backupPath);
        await file.delete();
        return await _connectWithRecovery(isRetry: true);
      }
    }
    rethrow;
  }
}
