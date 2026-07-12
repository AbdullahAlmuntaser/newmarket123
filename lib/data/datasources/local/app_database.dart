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

import 'package:uuid/uuid.dart';
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
import 'daos/recurring_entry_dao.dart';
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
part 'tables/leave_tables.dart';
part 'tables/attendance_tables.dart';
part 'tables/commission_credit_tables.dart';
part 'tables/tax_serial_tables.dart';
part 'tables/zakat_eosb_tables.dart';
part 'tables/proforma_tables.dart';
part 'tables/security_tables.dart';
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

class AccountTypeConverter extends TypeConverter<AccountType, int> {
  const AccountTypeConverter();
  @override
  AccountType fromSql(int fromDb) => AccountType.values[fromDb];
  @override
  int toSql(AccountType value) => value.index;
}

extension GLAccountX on GLAccount {
  String get type => accountType.name.toUpperCase();
}

class CentConverter extends TypeConverter<Decimal, int> {
  const CentConverter();
  @override
  Decimal fromSql(int fromDb) =>
      Decimal.fromInt(fromDb).shift(-2);
  @override
  int toSql(Decimal value) =>
      (value * Decimal.fromInt(100)).round().toBigInt().toInt();
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
  TextColumn get barcode => text().unique().nullable()(); // Primary barcode
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
  IntColumn get accountType => integer().map(const AccountTypeConverter())(); // ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE, COGS, OTHER_INCOME
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

  @override
  List<Set<Column>> get uniqueKeys => [
    {fiscalYear, status},
  ];
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
  TextColumn get branchId => text().nullable().references(Branches, #id)();
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
  IntColumn get totalAmount => integer().map(const CentConverter())();
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
  IntColumn get totalAmount => integer().map(const CentConverter())();
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
  TextColumn get branchId => text().nullable().references(Branches, #id)();
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
    RecurringEntries,
    RecurringEntryExecutions,
    HREmployees,
    HRPayrollRuns,
    HRPayrollDetails,
    HRAdditionalDeductions,
    LeaveTypes,
    LeaveRequests,
    LeaveBalances,
    AttendanceRecords,
    WithholdingTaxEntries,
    SerialNumbers,
    CreditNotes,
    CreditNoteItems,
    SalesTargets,
    SalesCommissions,
    ZakatCalculations,
    EndOfServiceBenefits,
    InventoryReservations,
    ProformaInvoices,
    ProformaInvoiceItems,
    ReconciliationDetails,
    UserSessions,
    LoginAttempts,
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
    RecurringEntryDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  /// Set externally before first instantiation to avoid circular import with SecurityService.
  static String? encryptionKey;

  @override
  int get schemaVersion => 50;

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
            } catch (e) {
              debugPrint('DB Migration v33: valuationMethod: $e');
            }
            try {
              await m.addColumn(products, products.allowFreeQty);
            } catch (e) {
              debugPrint('DB Migration v33: allowFreeQty: $e');
            }
            try {
              await m.addColumn(products, products.isService);
            } catch (e) {
              debugPrint('DB Migration v33: isService: $e');
            }
          }
          if (from < 34) {
            try {
              await m.addColumn(
                  goodReceivedNotes, goodReceivedNotes.purchaseId);
            } catch (e) {
              debugPrint('DB Migration v34: purchaseId: $e');
            }
            try {
              await m.addColumn(
                  goodReceivedNotes, goodReceivedNotes.supplierId);
            } catch (e) {
              debugPrint('DB Migration v34: supplierId: $e');
            }
          }
          if (from < 35) {
            try {
              await m.createTable(appConfigTable);
            } catch (e) {
              debugPrint('DB Migration v35: appConfigTable: $e');
            }
          }
          if (from < 36) {
            try {
              await m.addColumn(sales, sales.shippingCost);
            } catch (e) {
              debugPrint('DB Migration v36: shippingCost: $e');
            }
            try {
              await m.addColumn(sales, sales.otherExpenses);
            } catch (e) {
              debugPrint('DB Migration v36: otherExpenses: $e');
            }
            try {
              await m.addColumn(sales, sales.warehouseId);
            } catch (e) {
              debugPrint('DB Migration v36: warehouseId: $e');
            }
            try {
              await m.addColumn(sales, sales.representativeId);
            } catch (e) {
              debugPrint('DB Migration v36: representativeId: $e');
            }
          }
          if (from < 37) {
            try {
              await m.createTable(financialTransfers);
            } catch (e) {
              debugPrint('DB Migration v37: financialTransfers: $e');
            }
          }
          if (from < 38) {
            try {
              await m.createTable(productionOrders);
              await m.createTable(productionOrderItems);
            } catch (e) {
              debugPrint('DB Migration v38: production tables: $e');
            }
          }
          // NOTE: Performance indexes are NOT created here because later
          // migrations (e.g. from < 42) may recreate tables with new columns.
          // They are created safely in `beforeOpen` after ALL migrations finish.
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
            try {
              await m.addColumn(products, products.imagePath);
            } catch (e) {
              debugPrint('DB Migration v43: imagePath: $e');
            }
          }
          if (from < 44) {
            try {
              await m.createTable(recurringEntries);
            } catch (e) {
              debugPrint('DB Migration v44: recurringEntries: $e');
            }
            try {
              await m.createTable(recurringEntryExecutions);
            } catch (e) {
              debugPrint('DB Migration v44: recurringEntryExecutions: $e');
            }
          }
          if (from < 45) {
            try { await m.createTable(leaveTypes); } catch (e) { debugPrint('DB Migration v45: leaveTypes: $e'); }
            try { await m.createTable(leaveRequests); } catch (e) { debugPrint('DB Migration v45: leaveRequests: $e'); }
            try { await m.createTable(leaveBalances); } catch (e) { debugPrint('DB Migration v45: leaveBalances: $e'); }
            try { await m.createTable(attendanceRecords); } catch (e) { debugPrint('DB Migration v45: attendanceRecords: $e'); }
            try { await m.createTable(withholdingTaxEntries); } catch (e) { debugPrint('DB Migration v45: withholdingTaxEntries: $e'); }
            try { await m.createTable(serialNumbers); } catch (e) { debugPrint('DB Migration v45: serialNumbers: $e'); }
            try { await m.createTable(creditNotes); } catch (e) { debugPrint('DB Migration v45: creditNotes: $e'); }
            try { await m.createTable(creditNoteItems); } catch (e) { debugPrint('DB Migration v45: creditNoteItems: $e'); }
            try { await m.createTable(salesTargets); } catch (e) { debugPrint('DB Migration v45: salesTargets: $e'); }
            try { await m.createTable(salesCommissions); } catch (e) { debugPrint('DB Migration v45: salesCommissions: $e'); }
            try { await m.createTable(zakatCalculations); } catch (e) { debugPrint('DB Migration v45: zakatCalculations: $e'); }
            try { await m.createTable(endOfServiceBenefits); } catch (e) { debugPrint('DB Migration v45: endOfServiceBenefits: $e'); }
            try { await m.createTable(inventoryReservations); } catch (e) { debugPrint('DB Migration v45: inventoryReservations: $e'); }
          }
          if (from < 46) {
            try {
              await m.createTable(proformaInvoices);
            } catch (e) {
              debugPrint('DB Migration v46: proformaInvoices: $e');
            }
            try {
              await m.createTable(proformaInvoiceItems);
            } catch (e) {
              debugPrint('DB Migration v46: proformaInvoiceItems: $e');
            }
          }
          if (from < 47) {
            // Version 47: Critical Missing Tables Recovery (Self-healing)
            await _recoverMissingTables(m);
          }
          if (from < 48) {
            try {
              await customStatement('ALTER TABLE posting_profiles ADD COLUMN branch_id TEXT REFERENCES branches(id)');
            } catch (e) {
              debugPrint('DB Migration v48: branch_id: $e');
            }
          }
          if (from < 49) {
            // Version 49: Convert REAL monetary columns to INTEGER cents
            for (final stmt in _migrateToV49Statements) {
              try {
                await customStatement(stmt);
              } catch (e) {
                debugPrint('DB Migration v49: Failed executing statement: $e');
              }
            }
          }
          if (from < 50) {
            // Version 50: Add security tables (user_sessions, login_attempts)
            // and add ReconciliationDetails to schema
            try {
              await m.createTable(userSessions);
            } catch (e) {
              debugPrint('DB Migration v50: userSessions already exists or failed: $e');
            }
            try {
              await m.createTable(loginAttempts);
            } catch (e) {
              debugPrint('DB Migration v50: loginAttempts already exists or failed: $e');
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA synchronous = NORMAL;');
          
          if (details.wasCreated) {
            // First creation: run migrations + seed data + indexes
            // (migrations already ran via onCreate, just do extras)
            await ensurePerformanceIndexes();
            await ensureCoreReferenceData();
          } else {
            // Existing database: lightweight self-healing only
            // Skip recovery check if already verified (stored in app_config_table)
            if (!await _isRecoveryVerified()) {
              await _recoverMissingTables(createMigrator());
              await _markRecoveryVerified();
            }
            // Skip core data seeding if already verified
            if (!await _isCoreDataSeeded()) {
              await ensureCoreReferenceData();
              await _markCoreDataSeeded();
            }
            // Note: indexes are NOT re-created on every open.
            // They persist in the database file and only need
            // creation once. New indexes are added via migrations.
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
    'CREATE INDEX IF NOT EXISTS sales_order_number_idx ON sales_orders (order_number)',
    'CREATE INDEX IF NOT EXISTS posting_profiles_branch_id_idx ON posting_profiles (branch_id)',
    'CREATE INDEX IF NOT EXISTS reconciliation_details_branch_id_idx ON reconciliation_details (branch_id)',
    'CREATE INDEX IF NOT EXISTS purchase_orders_order_number_idx ON purchase_orders (order_number)',
    'CREATE INDEX IF NOT EXISTS purchase_orders_supplier_id_idx ON purchase_orders (supplier_id)',
    'CREATE INDEX IF NOT EXISTS account_transactions_account_id_idx ON account_transactions (account_id)',
    'CREATE INDEX IF NOT EXISTS account_transactions_date_idx ON account_transactions (date)',
    'CREATE INDEX IF NOT EXISTS checks_partner_id_idx ON checks (partner_id)',
    'CREATE INDEX IF NOT EXISTS checks_status_idx ON checks (status)',
    'CREATE INDEX IF NOT EXISTS checks_due_date_idx ON checks (due_date)',
    'CREATE INDEX IF NOT EXISTS stock_transfer_items_transfer_id_idx ON stock_transfer_items (transfer_id)',
    'CREATE INDEX IF NOT EXISTS good_received_note_items_grn_id_idx ON good_received_note_items (grn_id)',
    'CREATE INDEX IF NOT EXISTS delivery_note_items_delivery_note_id_idx ON delivery_note_items (delivery_note_id)',
    'CREATE INDEX IF NOT EXISTS production_order_items_production_order_id_idx ON production_order_items (production_order_id)',
    'CREATE INDEX IF NOT EXISTS sales_return_items_sales_return_id_idx ON sales_return_items (sales_return_id)',
    'CREATE INDEX IF NOT EXISTS purchase_return_items_purchase_return_id_idx ON purchase_return_items (purchase_return_id)',
    'CREATE INDEX IF NOT EXISTS price_list_items_list_id_idx ON price_list_items (price_list_id)',
    'CREATE INDEX IF NOT EXISTS price_list_items_product_id_idx ON price_list_items (product_id)',
    'CREATE INDEX IF NOT EXISTS promotions_category_id_idx ON promotions (category_id)',
    'CREATE INDEX IF NOT EXISTS promotions_product_id_idx ON promotions (product_id)',
    'CREATE INDEX IF NOT EXISTS price_history_product_id_idx ON price_history (product_id)',
    'CREATE INDEX IF NOT EXISTS financial_transfers_sender_idx ON financial_transfers (sender_account_id)',
    'CREATE INDEX IF NOT EXISTS financial_transfers_receiver_idx ON financial_transfers (receiver_account_id)',
    'CREATE INDEX IF NOT EXISTS gl_accounts_type_idx ON gl_accounts (account_type)',
    'CREATE INDEX IF NOT EXISTS gl_accounts_parent_id_idx ON gl_accounts (parent_id)',
    'CREATE INDEX IF NOT EXISTS cost_centers_parent_id_idx ON cost_centers (parent_id)',
    'CREATE INDEX IF NOT EXISTS cost_centers_type_idx ON cost_centers (type)',
    'CREATE INDEX IF NOT EXISTS product_batches_batch_number_idx ON product_batches (batch_number)',
    'CREATE INDEX IF NOT EXISTS employees_employee_code_idx ON employees (employee_code)',
    'CREATE INDEX IF NOT EXISTS accounting_periods_fiscal_year_idx ON accounting_periods (fiscal_year)',
    'CREATE INDEX IF NOT EXISTS recurring_entries_next_execution_idx ON recurring_entries (next_execution_date)',
    'CREATE INDEX IF NOT EXISTS recurring_entries_status_idx ON recurring_entries (status)',
    'CREATE INDEX IF NOT EXISTS recurring_entry_executions_recurring_id_idx ON recurring_entry_executions (recurring_entry_id)',
    // Additional indexes for improved query performance
    'CREATE INDEX IF NOT EXISTS customer_payments_sale_id_idx ON customer_payments (payment_date)',
    'CREATE INDEX IF NOT EXISTS supplier_payments_date_idx ON supplier_payments (payment_date)',
    'CREATE INDEX IF NOT EXISTS gl_entries_posted_by_idx ON gl_entries (posted_by)',
    'CREATE INDEX IF NOT EXISTS sales_exchange_rate_idx ON sales (exchange_rate)',
    'CREATE INDEX IF NOT EXISTS purchases_exchange_rate_idx ON purchases (exchange_rate)',
    'CREATE INDEX IF NOT EXISTS checks_check_number_idx ON checks (check_number)',
    'CREATE INDEX IF NOT EXISTS product_batches_cost_price_idx ON product_batches (cost_price)',
    'CREATE INDEX IF NOT EXISTS fixed_assets_category_id_idx ON fixed_assets (category_id)',
    'CREATE INDEX IF NOT EXISTS fixed_assets_status_idx ON fixed_assets (status)',
    'CREATE INDEX IF NOT EXISTS acc_budgets_cost_center_id_idx ON acc_budgets (cost_center_id)',
    'CREATE INDEX IF NOT EXISTS acc_budgets_period_idx ON acc_budgets (period)',
    'CREATE INDEX IF NOT EXISTS ap_invoices_supplier_id_idx ON a_p_invoices (supplier_id)',
    'CREATE INDEX IF NOT EXISTS ar_invoices_customer_id_idx ON a_r_invoices (customer_id)',
    'CREATE INDEX IF NOT EXISTS delivery_notes_sale_order_id_idx ON delivery_notes (sale_order_id)',
    'CREATE INDEX IF NOT EXISTS delivery_notes_status_idx ON delivery_notes (status)',
    'CREATE INDEX IF NOT EXISTS good_received_notes_purchase_id_idx ON good_received_notes (purchase_id)',
    'CREATE INDEX IF NOT EXISTS payroll_lines_employee_id_idx ON payroll_lines (employee_id)',
    'CREATE INDEX IF NOT EXISTS payroll_lines_payroll_entry_id_idx ON payroll_lines (payroll_entry_id)',
  ];

  Future<void> ensurePerformanceIndexes() async {
    // Use a single transaction for all index creations (much faster than individual statements)
    await customStatement('PRAGMA journal_mode = WAL;');
    for (final statement in _performanceIndexStatements) {
      try {
        await customStatement(statement);
      } catch (e) {
        // Index might already exist or table might not exist yet - safe to ignore
      }
    }
  }

  Future<void> _recoverMissingTables(Migrator m) async {
    // Single query to get all existing table names (instead of 105 individual queries)
    final existingRows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    ).get();
    final existingNames = existingRows.map((r) => r.data['name'] as String).toSet();

    var recoveredCount = 0;
    for (final table in allTables) {
      if (!existingNames.contains(table.actualTableName)) {
        try {
          debugPrint('DB Forensic: Recovering missing table: ${table.actualTableName}');
          await m.createTable(table);
          recoveredCount++;
        } catch (e) {
          debugPrint('DB Forensic: Failed to recover table ${table.actualTableName}: $e');
        }
      }
    }
    if (recoveredCount > 0) {
      debugPrint('DB Forensic: Recovered $recoveredCount missing tables');
    }
  }

  // ==================== STARTUP OPTIMIZATION FLAGS ====================
  // These flags are stored in app_config_table to skip expensive checks
  // on subsequent opens. They are idempotent and self-healing.

  static const _kRecoveryVerifiedKey = '_db_recovery_verified';
  static const _kCoreDataSeededKey = '_db_core_data_seeded';

  Future<bool> _isRecoveryVerified() async {
    try {
      final result = await customSelect(
        "SELECT value FROM app_config_table WHERE key = ?",
        variables: [const Variable(_kRecoveryVerifiedKey)],
      ).getSingleOrNull();
      return result?.data['value'] == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> _markRecoveryVerified() async {
    try {
      await customStatement(
        "INSERT OR REPLACE INTO app_config_table (key, value) VALUES (?, 'true')",
        [const Variable(_kRecoveryVerifiedKey)],
      );
    } catch (_) {}
  }

  Future<bool> _isCoreDataSeeded() async {
    try {
      final result = await customSelect(
        "SELECT value FROM app_config_table WHERE key = ?",
        variables: [const Variable(_kCoreDataSeededKey)],
      ).getSingleOrNull();
      return result?.data['value'] == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> _markCoreDataSeeded() async {
    try {
      await customStatement(
        "INSERT OR REPLACE INTO app_config_table (key, value) VALUES (?, 'true')",
        [const Variable(_kCoreDataSeededKey)],
      );
    } catch (_) {}
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
  @override
  RecurringEntryDao get recurringEntryDao => RecurringEntryDao(this);

  // --- Missing Methods Recovery ---

  Future<void> seedData() async {
    await ensureCoreReferenceData();
    await seedSecurityData();
    await seedDefaultGLAccounts();
    await seedDefaultPostingProfiles();
  }

  Future<void> ensureCoreReferenceData() async {
    await ensureDefaultBranch();
    await ensureDefaultCurrencies();
  }

  static const Map<String, String> _seedPermissions = {
    'POST_SALE': 'تسجيل المبيعات',
    'POST_PURCHASE': 'تسجيل المشتريات',
    'POST_SALE_RETURN': 'تسجيل مردودات المبيعات',
    'POST_PURCHASE_RETURN': 'تسجيل مردودات المشتريات',
    'DELETE_INVOICE': 'حذف الفواتير',
    'VOID_TRANSACTION': 'إلغاء الحركات',
    'MANAGE_USERS': 'إدارة المستخدمين',
    'VIEW_REPORTS': 'عرض التقارير',
    'MANAGE_SETTINGS': 'إدارة الإعدادات',
    'MANAGE_INVENTORY': 'إدارة المخزون',
    'APPROVE_DISCOUNT': 'الموافقة على الخصومات',
    'EDIT_TAX': 'تعديل الضريبة',
    'CREATE_SALES_ORDER': 'إنشاء طلبيات مبيعات',
    'EDIT_SALES_ORDER': 'تعديل طلبيات المبيعات',
    'DELETE_SALES_ORDER': 'حذف طلبيات المبيعات',
    'APPROVE_SALES_ORDER': 'الموافقة على طلبيات المبيعات',
    'PRINT_BARCODE': 'طباعة الباركود',
    'EXPORT_DATA': 'تصدير البيانات',
    'VIEW_CUSTOMER_REPORT': 'تقرير العملاء',
    'VIEW_SUPPLIER_REPORT': 'تقرير الموردين',
    'VIEW_PURCHASE_REPORT': 'تقرير المشتريات',
    'VIEW_CASHBOX_REPORT': 'تقرير الصناديق',
    'VIEW_INVENTORY_REPORT': 'تقرير المخزون',
    'VIEW_PROFIT_REPORT': 'تقرير الأرباح',
    'VIEW_PRODUCTS': 'عرض المنتجات',
    'CREATE_PRODUCT': 'إضافة منتج',
    'EDIT_PRODUCT': 'تعديل منتج',
    'DELETE_PRODUCT': 'حذف منتج',
    'VIEW_CUSTOMERS': 'عرض العملاء',
    'CREATE_CUSTOMER': 'إضافة عميل',
    'EDIT_CUSTOMER': 'تعديل عميل',
    'DELETE_CUSTOMER': 'حذف عميل',
    'VIEW_SUPPLIERS': 'عرض الموردين',
    'CREATE_SUPPLIER': 'إضافة مورد',
    'EDIT_SUPPLIER': 'تعديل مورد',
    'DELETE_SUPPLIER': 'حذف مورد',
    'VIEW_SALES': 'عرض المبيعات',
    'CREATE_SALE': 'إنشاء فاتورة مبيعات',
    'EDIT_SALE': 'تعديل فاتورة مبيعات',
    'VIEW_PURCHASES': 'عرض المشتريات',
    'CREATE_PURCHASE': 'إنشاء فاتورة مشتريات',
    'EDIT_PURCHASE': 'تعديل فاتورة مشتريات',
    'VIEW_MANUFACTURING': 'عرض التصنيع',
    'CREATE_MANUFACTURING': 'إنشاء أمر تصنيع',
    'VIEW_HR': 'عرض الموارد البشرية',
    'MANAGE_HR': 'إدارة الموارد البشرية',
    'VIEW_ACCOUNTING': 'عرض المحاسبة',
    'MANAGE_ACCOUNTING': 'إدارة المحاسبة',
    'VIEW_SALES_REPORT': 'تقرير المبيعات',
    'VIEW_ADVANCED_PROFIT_REPORT': 'تقرير الأرباح المتقدم',
    'VIEW_TOP_SELLING_REPORT': 'تقرير الأكثر مبيعاً',
    'VIEW_SLOW_MOVING_REPORT': 'تقرير المنتجات الراكدة',
    'VIEW_STOCK_MOVEMENT_REPORT': 'تقرير حركة المخزون',
    'VIEW_ITEM_MOVEMENT_REPORT': 'تقرير حركة الصنف',
    'VIEW_VAT_REPORT': 'تقرير ضريبة القيمة المضافة',
    'VIEW_AGING_REPORT': 'تقرير أعمار الديون',
    'VIEW_CASH_FLOW_REPORT': 'تقرير التدفق النقدي',
    'VIEW_AUDIT_REPORT': 'تقرير سجل التدقيق',
    'VIEW_EXPENSES_REPORT': 'تقرير المصروفات',
    'VIEW_INCOME_EXPENSE_REPORT': 'تقرير الإيرادات والمصروفات',
    'CREATE_JOURNAL_ENTRY': 'إنشاء قيد يومية',
    'APPROVE_JOURNAL_ENTRY': 'الموافقة على قيد يومية',
    'MANAGE_CASHBOX': 'إدارة الصناديق',
    'MANAGE_TRANSFERS': 'إدارة التحويلات',
    'MANAGE_CHECKS': 'إدارة الشيكات',
    'MANAGE_FIXED_ASSETS': 'إدارة الأصول الثابتة',
    'MANAGE_BUDGETS': 'إدارة الميزانيات',
    'CLOSE_PERIOD': 'إغلاق الفترة المحاسبية',
    'MANAGE_RECONCILIATION': 'إدارة التسوية البنكية',
  };

  Future<void> seedSecurityData() async {
    for (final entry in _seedPermissions.entries) {
      await into(permissions).insert(
        PermissionsCompanion.insert(
          code: entry.key,
          description: Value(entry.value),
        ),
        onConflict: DoUpdate(
          (_) => PermissionsCompanion(
            description: Value(entry.value),
          ),
          target: [permissions.code],
        ),
      );
    }

    const roles = ['admin', 'manager', 'cashier'];
    for (final role in roles) {
      final existingCount = await (select(rolePermissions)
            ..where((rp) => rp.role.equals(role)))
          .get()
          .then((list) => list.length);
      if (existingCount > 0) continue;

      final pCodes = _seedPermissions.keys.toList();
      for (final pCode in pCodes) {
        if (role == 'admin' ||
            (role == 'manager' && pCode != 'MANAGE_USERS') ||
            (role == 'cashier' && pCode == 'POST_SALE')) {
          await into(rolePermissions).insert(RolePermissionsCompanion.insert(
            role: role,
            permissionCode: pCode,
          ));
        }
      }
    }
  }

  /// Seeds the default GL accounts required for the posting engine.
  /// Called automatically on first database creation.
  Future<void> seedDefaultGLAccounts() async {
    final existingAccounts = await select(gLAccounts).get();
    if (existingAccounts.isNotEmpty) return;

    final accounts = {
      '1010': GLAccountsCompanion.insert(code: '1010', name: 'الصندوق', accountType: AccountType.asset),
      '1020': GLAccountsCompanion.insert(code: '1020', name: 'البنك', accountType: AccountType.asset),
      '1030': GLAccountsCompanion.insert(code: '1030', name: 'الذمم المدينة', accountType: AccountType.asset),
      '1040': GLAccountsCompanion.insert(code: '1040', name: 'المخزون', accountType: AccountType.asset),
      '1050': GLAccountsCompanion.insert(code: '1050', name: 'ضريبة المدخلات', accountType: AccountType.asset),
      '1200': GLAccountsCompanion.insert(code: '1200', name: 'الأصول الثابتة', accountType: AccountType.asset),
      '1201': GLAccountsCompanion.insert(code: '1201', name: 'مجمع الإهلاك', accountType: AccountType.asset),
      '2010': GLAccountsCompanion.insert(code: '2010', name: 'الذمم الدائنة', accountType: AccountType.liability),
      '2020': GLAccountsCompanion.insert(code: '2020', name: 'ضريبة المخرجات', accountType: AccountType.liability),
      '2500': GLAccountsCompanion.insert(code: '2500', name: 'القروض', accountType: AccountType.liability),
      '3000': GLAccountsCompanion.insert(code: '3000', name: 'رأس المال', accountType: AccountType.equity),
      '3010': GLAccountsCompanion.insert(code: '3010', name: 'الأرباح المحتجزة', accountType: AccountType.equity),
      '4010': GLAccountsCompanion.insert(code: '4010', name: 'إيرادات المبيعات', accountType: AccountType.revenue),
      '4020': GLAccountsCompanion.insert(code: '4020', name: 'مردودات المبيعات', accountType: AccountType.revenue),
      '5010': GLAccountsCompanion.insert(code: '5010', name: 'تكلفة البضاعة المباعة', accountType: AccountType.expense),
      '5011': GLAccountsCompanion.insert(code: '5011', name: 'مردودات المشتريات', accountType: AccountType.expense),
      '5020': GLAccountsCompanion.insert(code: '5020', name: 'العجز والزيادة في الصندوق', accountType: AccountType.expense),
      '6000': GLAccountsCompanion.insert(code: '6000', name: 'المصروفات التشغيلية', accountType: AccountType.expense),
      '6001': GLAccountsCompanion.insert(code: '6001', name: 'مصروف الإهلاك', accountType: AccountType.expense),
    };

    for (final acc in accounts.values) {
      await into(gLAccounts).insert(acc);
    }
  }

  /// Seeds default posting profiles so the posting engine can resolve accounts.
  /// Called automatically on first database creation.
  Future<void> seedDefaultPostingProfiles() async {
    final existing = await select(postingProfiles).get();
    if (existing.isNotEmpty) return;

    // Map of (operationType, accountType) -> (accountCode, side)
    const profileDefs = [
      // SALE profiles
      ('SALE', 'RECEIVABLE', '1030', 'DEBIT'),
      ('SALE', 'REVENUE', '4010', 'CREDIT'),
      ('SALE', 'OUTPUT_VAT', '2020', 'CREDIT'),
      ('SALE', 'COGS', '5010', 'DEBIT'),
      ('SALE', 'INVENTORY', '1040', 'CREDIT'),
      // PURCHASE profiles
      ('PURCHASE', 'INVENTORY', '1040', 'DEBIT'),
      ('PURCHASE', 'INPUT_VAT', '1050', 'DEBIT'),
      ('PURCHASE', 'PAYABLE', '2010', 'CREDIT'),
      // SALE_RETURN profiles
      ('SALE_RETURN', 'RECEIVABLE', '1030', 'CREDIT'),
      ('SALE_RETURN', 'RETURN', '4020', 'DEBIT'),
      // PURCHASE_RETURN profiles
      ('PURCHASE_RETURN', 'PAYABLE', '2010', 'DEBIT'),
      ('PURCHASE_RETURN', 'RETURN', '5011', 'CREDIT'),
      // CUSTOMER_PAYMENT profiles
      ('CUSTOMER_PAYMENT', 'CASH', '1010', 'DEBIT'),
      ('CUSTOMER_PAYMENT', 'RECEIVABLE', '1030', 'CREDIT'),
      // SUPPLIER_PAYMENT profiles
      ('SUPPLIER_PAYMENT', 'PAYABLE', '2010', 'DEBIT'),
      ('SUPPLIER_PAYMENT', 'CASH', '1010', 'CREDIT'),
      // CASH_TRANSACTION profiles
      ('CASH_TRANSACTION', 'CASH', '1010', 'DEBIT'),
    ];

    for (final def in profileDefs) {
      final (operationType, accountType, accountCode, side) = def;
      // Find the GL account by code
      final account = await (select(gLAccounts)
            ..where((a) => a.code.equals(accountCode)))
          .getSingleOrNull();
      await into(postingProfiles).insert(
        PostingProfilesCompanion.insert(
          operationType: operationType,
          accountType: accountType,
          accountId: Value(account?.id),
          accountCode: Value(accountCode),
          side: side,
        ),
      );
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

  static final List<String> _migrateToV49Statements = [
    // APInvoices: REAL → cents
    'UPDATE ap_invoices SET total_amount = CAST(ROUND(total_amount * 100) AS INTEGER)',
    // ARInvoices: REAL → cents
    'UPDATE ar_invoices SET total_amount = CAST(ROUND(total_amount * 100) AS INTEGER)',
    // HREmployees: REAL → cents
    'UPDATE hr_employees SET basic_salary = CAST(ROUND(basic_salary * 100) AS INTEGER), housing_allowance = CAST(ROUND(housing_allowance * 100) AS INTEGER), transport_allowance = CAST(ROUND(transport_allowance * 100) AS INTEGER), other_allowances = CAST(ROUND(other_allowances * 100) AS INTEGER), total_deductions = CAST(ROUND(total_deductions * 100) AS INTEGER)',
    // HRPayrollRuns: REAL → cents
    'UPDATE hr_payroll_runs SET total_salaries = CAST(ROUND(total_salaries * 100) AS INTEGER), total_allowances = CAST(ROUND(total_allowances * 100) AS INTEGER), total_deductions = CAST(ROUND(total_deductions * 100) AS INTEGER), net_payable = CAST(ROUND(net_payable * 100) AS INTEGER)',
    // HRPayrollDetails: REAL → cents
    'UPDATE hr_payroll_details SET basic_salary = CAST(ROUND(basic_salary * 100) AS INTEGER), housing_allowance = CAST(ROUND(housing_allowance * 100) AS INTEGER), transport_allowance = CAST(ROUND(transport_allowance * 100) AS INTEGER), other_allowances = CAST(ROUND(other_allowances * 100) AS INTEGER), gross_salary = CAST(ROUND(gross_salary * 100) AS INTEGER), deductions = CAST(ROUND(deductions * 100) AS INTEGER), net_salary = CAST(ROUND(net_salary * 100) AS INTEGER)',
    // HRAdditionalDeductions: REAL → cents
    'UPDATE hr_additional_deductions SET amount = CAST(ROUND(amount * 100) AS INTEGER)',
  ];

  Future<void> _migrateToV42(Migrator m) async {
    // Re-create tables with new types (Decimal instead of Real)
    // We use individual try-catches to ensure one missing table doesn't stop the whole migration
    final tablesToRecreate = [
      (stockTakeItems, 'stock_take_items'),
      (goodReceivedNoteItems, 'good_received_note_items'),
      (deliveryNoteItems, 'delivery_note_items'),
      (checks, 'checks'),
      (purchaseOrders, 'purchase_orders'),
      (purchaseOrderItems, 'purchase_order_items'),
      (salesOrders, 'sales_orders'),
      (salesOrderItems, 'sales_order_items'),
      (customerPaymentLinks, 'customer_payment_links'),
    ];

    for (final entry in tablesToRecreate) {
      final table = entry.$1 as TableInfo;
      final name = entry.$2;
      try {
        await m.deleteTable(name);
        await m.createTable(table);
      } catch (e) {
        debugPrint('Migration to V42: Failed to recreate $name (might not exist): $e');
        try {
          await m.createTable(table);
        } catch (_) {} // If delete failed because it didn't exist, try creating anyway
      }
    }

    try {
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
    } catch (e) {
      debugPrint('Migration to V42 (Currency Copy) failed: $e');
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
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final backupPath = "${file.path}.${suffix}_$timestamp";

  try {
    // Preserve original file for debugging before deletion
    await file.copy(backupPath);
    debugPrint("DB: File backed up to $backupPath (${await file.length()} bytes)");
  } catch (copyError) {
    debugPrint("DB: WARNING - Failed to create backup: $copyError");
    // Continue with deletion even if backup fails — the file is already corrupted
  }

  try {
    await file.delete();
    debugPrint("DB: Original file deleted.");
  } catch (deleteError) {
    debugPrint("DB: WARNING - Failed to delete file: $deleteError");
  }
}

/// Converts an unencrypted SQLite database at [file] to the SQLCipher format
/// using [key].
Future<File> _convertToEncrypted(File file, String key) async {
  // Pre-check: verify SQLCipher was loaded
  if (!isSqlCipherLoaded) {
    throw Exception(
        'CONVERSION_FAILED: SQLCipher library is not loaded. '
        'Cannot convert plain SQLite to encrypted database.');
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final tempPath = '${file.path}.encrypted_$timestamp';
  final tempFile = File(tempPath);

  debugPrint("DB ENCRYPT: Converting unencrypted SQLite -> SQLCipher...");

  final escapedKey = key.replaceAll("'", "''");
  final escapedTempPath = tempPath.replaceAll("'", "''");

  try {
    final db = sqlite.sqlite3.open(file.path);
    try {
      // Set cipher_page_size before ATTACH to ensure the encrypted database
      // uses the same cipher_page_size as _openNativeDatabase.
      db.execute('PRAGMA cipher_page_size = 4096');
      db.execute(
          "ATTACH DATABASE '$escapedTempPath' AS encrypted KEY '$escapedKey'");
      db.execute("SELECT sqlcipher_export('encrypted')");
      db.execute("DETACH DATABASE encrypted");
    } finally {
      db.dispose();
    }

    // Verify the encrypted file exists and is valid
    if (!await tempFile.exists()) {
      throw Exception(
          'CONVERSION_FAILED: Encrypted temporary file was not created at $tempPath');
    }

    final verifyDb = sqlite.sqlite3.open(tempPath);
    try {
      // Use identical cipher_page_size setting as _openNativeDatabase
      verifyDb.execute('PRAGMA cipher_page_size = 4096');
      verifyDb.execute("PRAGMA key = '$escapedKey'");
      final result = verifyDb.select("PRAGMA integrity_check;");
      if (result.first.values.first != 'ok') {
        throw Exception(
            "CONVERSION_FAILED: Encrypted DB integrity check failed. "
            "The encrypted file may be corrupted.");
      }
    } finally {
      verifyDb.dispose();
    }

    // Backup the original unencrypted file before replacing
    final backupPath = '${file.path}.unencrypted_backup_$timestamp';
    await file.copy(backupPath);
    debugPrint("DB ENCRYPT: Unencrypted backup saved to: $backupPath");

    await file.delete();
    await tempFile.rename(file.path);

    debugPrint("DB ENCRYPT: Conversion successful. Database is now encrypted.");
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

    debugPrint("DB: _connectWithRecovery called. isRetry=$isRetry, "
        "file.exists=${await file.exists()}, "
        "sqlCipherLoaded=$isSqlCipherLoaded, "
        "encryptionKey=${AppDatabase.encryptionKey != null ? 'set(${AppDatabase.encryptionKey!.length} chars)' : 'null'}");

    if (await file.exists()) {
      final size = await file.length();
      debugPrint("DB: Existing file size=$size bytes");
      if (size == 0) {
        await file.delete();
        debugPrint("DB: Deleted empty database file.");
      } else if (size < 100) {
        await _backupAndDelete(file, 'corrupted');
        debugPrint("DB: Backed up and deleted tiny database file ($size bytes).");
      }
    } else {
      debugPrint("DB: No existing database file. Fresh install.");
    }

    final encryptionKey = AppDatabase.encryptionKey;

    if (encryptionKey != null && await file.exists()) {
      if (await _isPlainSqliteDatabase(file)) {
        debugPrint("DB: Plain SQLite database detected. Converting to encrypted...");
        try {
          await _convertToEncrypted(file, encryptionKey);
          if (await file.exists() && await _isPlainSqliteDatabase(file)) {
            throw Exception(
                'CONVERSION_FAILED: Database is still plain SQLite after conversion attempt.');
          }
          debugPrint("DB: Successfully converted plain DB to encrypted.");
        } catch (e) {
          debugPrint("DB: ERROR: Failed to convert plain DB to encrypted: $e");
          rethrow;
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Pre-validation: test the encryption key before the main open below.
    // If the key doesn't match, the database is deleted so _openNativeDatabase
    // can create a fresh encrypted database with the correct key.
    // ═══════════════════════════════════════════════════════════════════════
    if (encryptionKey != null && await file.exists() && isSqlCipherLoaded) {
      debugPrint("DB PRE-VALIDATE: Verifying encryption key against existing database...");
      final escapedKey = encryptionKey.replaceAll("'", "''");
      try {
        final testDb = sqlite.sqlite3.open(file.path);
        try {
          testDb.execute("PRAGMA cipher_page_size = 4096");
          testDb.execute("PRAGMA key = '$escapedKey'");
          final result = testDb.select("PRAGMA integrity_check;");
          final status = result.isNotEmpty ? result.first.values.first : 'unknown';
          debugPrint("DB PRE-VALIDATE: integrity_check = $status");
          if (status != 'ok') {
            debugPrint("DB PRE-VALIDATE: INTEGRITY FAILED — deleting database for recreation.");
            await _backupAndDelete(file, 'integrity_failed');
          }
        } finally {
          testDb.dispose();
        }
      } catch (e) {
        final s = e.toString();
        debugPrint("DB PRE-VALIDATE: FAILED — $s");
        if (s.contains('code 26') ||
            s.contains('file is not a database') ||
            s.contains('SqliteException')) {
          debugPrint("DB PRE-VALIDATE: Key mismatch or corruption. Deleting database for recreation.");
          await _backupAndDelete(file, 'key_mismatch');
        }
      }
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite.sqlite3.tempDirectory = cachebase;

    try {
      debugPrint("DB: Attempting to open database (attempt ${isRetry ? '2' : '1'})...");
      return await _openNativeDatabase(file, encryptionKey);
    } catch (e) {
      final s = e.toString();
      debugPrint("DB: Open failed: $s");

      if (!isRetry &&
          encryptionKey != null &&
          (s.contains('code 26') || s.contains('DATABASE_ENCRYPTION_ERROR') || s.contains('file is not a database'))) {
        debugPrint("DB: Encryption error detected. Attempting recovery...");

        // Step 1: Try legacy KDF
        if (await file.exists()) {
          debugPrint("DB: Step 1 - Trying SQLCipher 3 legacy settings...");
          try {
            return await _openNativeDatabase(file, encryptionKey, useLegacyKdf: true);
          } catch (legacyError) {
            debugPrint("DB: Legacy settings also failed: $legacyError");
          }
        }

        // Step 2: Always delete and recreate on encryption error
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint("DB: Step 2 - Deleting corrupted file ($fileSize bytes) and recreating...");
          await _backupAndDelete(file, 'recovery');
          debugPrint("DB: File deleted. Retrying fresh creation...");
          try {
            return await _openNativeDatabase(file, encryptionKey);
          } catch (retryError) {
            debugPrint("DB: Fresh creation also failed: $retryError");
          }
        }

        debugPrint("DB: All recovery attempts exhausted.");
      }
      rethrow;
    }
  } catch (e) {
    final s = e.toString();
    if (s.contains('code 26') || s.contains('DATABASE_ENCRYPTION_ERROR') || s.contains('file is not a database')) {
      debugPrint("DB: FINAL ERROR - Encryption/decryption error. Error: $e");
    } else {
      debugPrint("DB: FINAL ERROR - $e");
    }
    rethrow;
  }
}

Future<QueryExecutor> _openNativeDatabase(
  File file,
  String? encryptionKey, {
  bool useLegacyKdf = false,
}) async {
  debugPrint("DB: _openNativeDatabase called. "
      "file=${file.path}, "
      "encryptionKey=${encryptionKey != null ? 'set(${encryptionKey.length} chars)' : 'null'}, "
      "useLegacyKdf=$useLegacyKdf, "
      "sqlCipherLoaded=$isSqlCipherLoaded");

  // Pre-check: verify SQLCipher was loaded before attempting to open
  if (encryptionKey != null && !isSqlCipherLoaded) {
    throw Exception(
        'NO_SQLCIPHER: The SQLCipher native library was not loaded. '
        'Database encryption requires SQLCipher. '
        'Ensure sqlcipher_flutter_libs is properly included in the build.');
  }

  // Use the synchronous NativeDatabase(File, setup:) constructor (NOT
  // createInBackground) to avoid the background isolate closure capture
  // issue. The setup callback here runs in the main isolate where captured
  // variables like encryptionKey are correctly available.
  // Drift docs confirm: createInBackground's setup "must be a static or
  // top-level function" because it runs in another isolate.
  return NativeDatabase(
    file,
    logStatements: kDebugMode,
    setup: (rawDb) {
      debugPrint("DB SETUP: setup callback invoked in main isolate");
      if (encryptionKey != null) {
        final escapedKey = encryptionKey.replaceAll("'", "''");
        if (useLegacyKdf) {
          debugPrint("DB SETUP: Executing PRAGMA kdf_iter = 64000");
          rawDb.execute('PRAGMA kdf_iter = 64000');
        }
        debugPrint("DB SETUP: Executing PRAGMA cipher_page_size = 4096");
        rawDb.execute('PRAGMA cipher_page_size = 4096');
        debugPrint("DB SETUP: Executing PRAGMA key");
        rawDb.execute("PRAGMA key = '$escapedKey'");
        try {
          debugPrint("DB SETUP: Executing PRAGMA cipher_version");
          final cv = rawDb.select('PRAGMA cipher_version;');
          final cvValue = cv.isNotEmpty ? cv.first.values.first : null;
          debugPrint("DB SETUP: cipher_version result: $cvValue");
          if (cvValue == null || (cvValue is String && cvValue.isEmpty)) {
            throw Exception('NO_SQLCIPHER');
          }

          debugPrint("DB SETUP: Executing SELECT count(*) FROM sqlite_master");
          rawDb.execute('SELECT count(*) FROM sqlite_master;');
          debugPrint("DB SETUP: SELECT count(*) succeeded");
        } catch (e) {
          final s = e.toString();
          debugPrint("DB SETUP: Verification failed: $s");
          if (s.contains('NO_SQLCIPHER')) {
            throw Exception(
                'NO_SQLCIPHER: The loaded native library does not support SQLCipher encryption. '
                'PRAGMA cipher_version returned empty. '
                'Ensure sqlcipher_flutter_libs is properly bundled.');
          }
          if (s.contains('code 26') || s.contains('file is not a database')) {
            throw Exception(
                'DATABASE_ENCRYPTION_ERROR: Failed to open encrypted database. '
                'The encryption key may be incorrect or the database file may be corrupted. '
                'Original error: $s');
          }
          rethrow;
        }
      } else {
        debugPrint("DB SETUP: No encryption key, opening plain database");
      }
    },
  );
}
