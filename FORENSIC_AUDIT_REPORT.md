# Forensic ERP Audit Report — newmarket123

**Project**: `supermarket` (Flutter 3.4+ / Drift / SQLCipher / Provider + Bloc / GoRouter)  
**Database**: 50+ tables, encrypted SQLite via SQLCipher  
**Services**: 80+ registered services  
**Tests**: 27 test files  
**Date**: 2026-07-12

---

## Table of Contents
1. [System Architecture Overview](#1-system-architecture-overview)
2. [Critical Findings](#2-critical-findings)
3. [High Priority Findings](#3-high-priority-findings)
4. [Medium Priority Findings](#4-medium-priority-findings)
5. [Low Priority Findings](#5-low-priority-findings)
6. [Database Schema Issues](#6-database-schema-issues)
7. [Security Issues](#7-security-issues)
8. [Performance Issues](#8-performance-issues)
9. [Test Coverage Gaps](#9-test-coverage-gaps)
10. [Complete Fix Plan](#10-complete-fix-plan)

---

## 1. System Architecture Overview

### 1.1 Technology Stack
| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter 3.4+ |
| Database ORM | Drift (SQLite) with SQLCipher encryption |
| State Management | Provider + Bloc (POS only) |
| Dependency Injection | GetIt |
| Routing | GoRouter |
| Localization | Flutter l10n (AR/EN) |
| Security | BCrypt + flutter_secure_storage |

### 1.2 Architecture Pattern
```
lib/
├── core/                    # Cross-cutting concerns
│   ├── auth/                # Authentication & authorization
│   ├── constants/           # Enums, account codes, colors
│   ├── di/                  # Dependency injection modules
│   ├── events/              # Event bus events
│   ├── extensions/          # Extension methods
│   ├── models/              # Core domain models (accounting, inventory)
│   ├── navigation/          # GoRouter configuration
│   ├── services/            # 80+ business services
│   └── theme/               # App theming & localization
├── data/                    # Data layer
│   ├── datasources/local/   # Drift database, DAOs, tables, migrations
│   ├── mappers/             # Entity mappers
│   ├── models/              # Data models (quotation, GL entries)
│   └── repositories/        # Repository implementations
├── domain/                  # Domain layer
│   ├── entities/            # Domain entities
│   ├── repositories/        # Abstract repository interfaces
│   ├── services/            # Domain services (FEFO, approval)
│   └── usecases/            # Use cases
├── l10n/                    # Localization files (AR, EN)
├── presentation/            # Presentation layer
│   ├── blocs/               # BLoC state management
│   ├── features/            # Feature modules (20+ modules)
│   │   ├── accounting/      # Accounting pages & providers
│   │   ├── sales/           # Sales pages & providers
│   │   ├── purchases/       # Purchases pages & providers
│   │   ├── inventory/       # Inventory pages & providers
│   │   ├── pos/             # POS (Bloc-based)
│   │   ├── products/        # Products & categories
│   │   ├── customers/       # Customer management
│   │   ├── suppliers/       # Supplier management
│   │   ├── reports/         # 25+ report pages
│   │   ├── hr/              # HR, payroll, attendance
│   │   ├── manufacturing/   # BOM & production orders
│   │   └── ...              # Other feature modules
│   └── widgets/             # Shared widgets
└── injection_container.dart # DI container setup
```

### 1.3 Database Schema (50+ Tables)

**Core Tables:**
- `branches`, `users`, `categories`, `products`, `customers`, `suppliers`
- `sales`, `sale_items`, `purchases`, `purchase_items`
- `warehouses`, `product_batches`, `stock_movements`
- `gl_accounts`, `gl_entries`, `gl_lines`
- `accounting_periods`, `cost_centers`

**Extended Tables:**
- `sales_returns`, `sales_return_items`
- `purchase_returns`, `purchase_return_items`
- `customer_payments`, `supplier_payments`
- `customer_payment_links`, `purchase_payment_links`
- `stock_transfers`, `stock_transfer_items`
- `inventory_audits`, `inventory_audit_items`
- `stock_takes`, `stock_take_items`
- `good_received_notes`, `grn_items`
- `delivery_notes`, `delivery_note_items`
- `sales_orders`, `sales_order_items`
- `purchase_orders`, `purchase_order_items`
- `price_lists`, `price_list_items`
- `promotions`
- `bill_of_materials`, `production_orders`, `production_order_items`
- `checks`, `currencies`, `exchange_rates`
- `account_transactions`, `inventory_transactions`
- `employees`, `payroll_entries`, `payroll_lines`
- `shifts`, `reconciliations`, `reconciliation_details`
- `audit_logs`, `sync_queue`
- `permissions`, `role_permissions`
- `posting_profiles`
- `cashbox_transactions`, `financial_transfers`
- `unit_conversions`, `price_history`
- `ap_invoices`, `ar_invoices`
- `item_variants`

### 1.4 Transaction Flow

```
Sales Flow:
  SalesInvoicePage → _saveInvoice()
    → SalesDao.createSale() [DB insert]
    → TransactionEngine.postSale() [if posted]
      → Check accounting period
      → Deduct stock from product_batches (FIFO/FEFO)
      → Update products.stock
      → Create inventory_transactions
      → Update customer balance (if credit)
      → PostingEngine.post(TransactionType.sale)
        → Create GLEntry + GLLines (revenue, tax, receivable/cash)
        → Create GLEntry + GLLines (COGS, inventory)
      → Audit log
      → Fire event

Purchase Flow:
  AddPurchasePage → _savePurchase()
    → PurchasesDao.createPurchase() [DB insert]
    → PurchaseService.postPurchase() [if posted]
      → Check GRN exists
      → Check posting period
      → PostingEngine.post(TransactionType.purchase)
        → Create GLEntry + GLLines (inventory, tax, payable/cash)
      → Update purchase status

  TransactionEngine.postPurchase() [from purchase_orders_page or direct]
    → Check accounting period
    → Create batches (product_batches)
    → Update products.stock
    → Create inventory_transactions
    → Update supplier balance (if credit)
    → PostingEngine.post(TransactionType.purchase)
    → Audit log

Return Flow:
  ReturnService.processSalesReturn()
    → Record return + items
    → Update stock (+ return quantity)
    → Update batches
    → Create accounting entries (revenue reversal + COGS reversal)
    → Audit log

  TransactionEngine.postSaleReturn()
    → Similar but uses costing service
```

### 1.5 Accounting Posting Rules

| Transaction | Debit | Credit |
|------------|-------|--------|
| Cash Sale | Cash (1010) | Revenue (4010) + Output VAT (2020) |
| Credit Sale | Receivable (1030) | Revenue (4010) + Output VAT (2020) |
| COGS Entry | COGS (5010) | Inventory (1040) |
| Cash Purchase | Inventory (1040) + Input VAT (1050) | Cash (1010) |
| Credit Purchase | Inventory (1040) + Input VAT (1050) | Payable (2010) |
| Sale Return | Sales Returns (4020) | Cash (1010) / Receivable (1030) |
| Purchase Return | Cash (1010) / Payable (2010) | Purchase Returns (5011) |
| Customer Payment | Cash (1010) | Receivable (1030) |
| Supplier Payment | Payable (2010) | Cash (1010) |
| Cash Receipt | Cash (1010) | Account specified |
| Cash Payment | Account specified | Cash (1010) |

---

## 2. Critical Findings

### C1. NO ACCOUNTING POSTING TESTS

**Severity**: CRITICAL  
**Location**: `test/` (entire test suite)  
**Description**: No test verifies that a sale, purchase, or return creates correct GL entries. The 27 existing test files cover DB operations, widget rendering, pricing logic, and costing math — but none validate the double-entry accounting output.

**Evidence**:
- `test/services/accounting_service_test.dart` (209 lines) — tests ratios, VAT, reports, NOT posting
- `test/integration/sales_workflow_test.dart` (223 lines) — tests DB flow, NOT accounting entries
- `test/logic/posting_engine_test.dart` (61 lines) — only validates `validatePostingLines()`, not actual posting
- No test file imports `GLEntry`, `GLLine`, or `PostingEngine.post()`

**Impact**: Silent accounting errors will go undetected. A bug in posting logic could corrupt financial data without any test catching it.

**Fix Required**: Create integration tests that:
1. Create a sale → verify GL entries balance
2. Create a purchase → verify GL entries balance  
3. Create a return → verify GL entries balance
4. Verify account balances match expected values
5. Verify trial balance = 0 after transactions

### C2. NO FULL ACCOUNTING CYCLE INTEGRATION TEST

**Severity**: CRITICAL  
**Location**: `test/` (entire test suite)  
**Description**: No test covers the complete accounting cycle: Sale → Payment → Return → Period Close → Financial Reports.

**Evidence**:
- No test validates: Trial Balance = 0 after all entries
- No test validates: Balance Sheet (Assets = Liabilities + Equity)
- No test validates: Income Statement matches net income change
- `test/integration/comprehensive_workflow_test.dart` (193 lines) — tests sales/purchases/tax but NOT accounting

**Impact**: Core accounting integrity (debits = credits) is never verified end-to-end.

### C3. PERIOD CLOSING NOT ENFORCED IN UI

**Severity**: CRITICAL  
**Location**: All transaction pages  
**Description**: `PostingEngine._checkPeriodOpen()` correctly blocks posting to closed periods at the engine level. However:
1. UI screens don't warn users about closed periods during data entry
2. Users can fill an entire invoice before getting a "period is closed" error at save time
3. UX shows no visual indicator of current period status

**Evidence**:
- `sales_invoice_page.dart` — no period status check before showing the form
- `add_purchase_page.dart` — no period status check before showing the form
- `AccountingPeriodsPage` exists but isn't checked on transaction pages

**Impact**: Poor UX — users waste time entering data that will be rejected.

---

## 3. High Priority Findings

### H1. MISSING INDEXES ON FOREIGN KEYS

**Severity**: HIGH  
**Location**: `app_database.dart` (table definitions)  
**Description**: Multiple tables with frequent FK-based queries lack explicit indexes. Drift/SQLite does NOT auto-index foreign keys.

**Impact Areas**:
- Loading sale items (N+1 on each invoice load)
- Loading purchase items (N+1 on each invoice load)
- GL entry lines queries (slow report generation)
- Product batch lookups (slow inventory queries)
- Inventory transaction queries

**Tables & Columns Missing Indexes**:

| Table | Column(s) | Query Pattern |
|-------|-----------|---------------|
| `sale_items` | `sale_id` | `WHERE sale_id = ?` |
| `purchase_items` | `purchase_id` | `WHERE purchase_id = ?` |
| `gl_lines` | `entry_id` | `WHERE entry_id = ?` |
| `gl_lines` | `account_id` | `WHERE account_id = ?` |
| `product_batches` | `product_id, warehouse_id` | `WHERE product_id = ? AND warehouse_id = ?` |
| `inventory_transactions` | `product_id, warehouse_id` | `WHERE product_id = ? AND warehouse_id = ?` |
| `stock_movements` | `product_id` | `WHERE product_id = ?` |
| `sale_items` | `product_id` | `WHERE product_id = ?` |
| `purchase_items` | `product_id` | `WHERE product_id = ?` |

### H2. WAREHOUSE-LEVEL STOCK NOT TRACKED PER SALE ITEM

**Severity**: HIGH  
**Location**: `TransactionEngine.postSale()` (lines 238-443), `SaleItems` table  
**Description**: 
- `TransactionEngine.postSale()` deducts from `products.stock` (aggregate product-level)
- `SaleItems.warehouseId` column exists but is NOT referenced in stock deduction logic
- `InventoryTransactions` records warehouse, but no per-warehouse stock field exists on `Warehouses` table

**Evidence**:
```dart
// TransactionEngine.postSale() — line 337-342
await (db.update(db.products)..where((p) => p.id.equals(item.productId)))
    .write(ProductsCompanion(stock: Value(product.stock - totalDeducted)));
// NOTE: Only updates products.stock, NOT warehouse-level stock
```

**Impact**: Multi-warehouse users get incorrect per-location stock. A warehouse might show available stock that's actually in another warehouse.

### H3. BUDGET CONTROL NOT WIRED TO TRANSACTIONS

**Severity**: HIGH  
**Location**: `TransactionEngine` (all methods)  
**Description**: 
- `BudgetService` is fully registered in DI
- `TransactionEngine.setBudgetService()` method exists
- `TransactionEngine._budgetService` field exists
- **NEVER CALLED** — no transaction checks budget limits before posting

**Evidence**:
```dart
// TransactionEngine has:
BudgetService? _budgetService;
void setBudgetService(BudgetService budgetService) {
  _budgetService = budgetService;
}
// But _budgetService is never referenced in postSale(), postPurchase(), etc.
```

**Impact**: Budgets are decorative only — users can exceed budgets without warning.

### H4. INCONSISTENT PURCHASE POSTING PATHS

**Severity**: HIGH  
**Location**: `PurchaseService.postPurchase()` vs `TransactionEngine.postPurchase()`  
**Description**: Two different code paths for posting a purchase with different validation:
1. `PurchaseService.postPurchase()` — checks for POSTED GRN, then calls `PostingEngine.post()` directly
2. `TransactionEngine.postPurchase()` — handles stock/batches directly, does NOT check GRN

**Evidence**:
- `PurchaseService.postPurchase()` (purchase_service.dart:54-138) — GRN check + PostingEngine only
- `TransactionEngine.postPurchase()` (transaction_engine.dart:67-236) — full stock/batch handling + PostingEngine

**Impact**: Depending on which path is called, different validations apply. The GRN requirement can be bypassed.

### H5. CURRENCY EXCHANGE DIFFERENCE POSTING MISSING

**Severity**: HIGH  
**Location**: All posting methods  
**Description**: 
- Multi-currency schema: `Currencies`, `ExchangeRates`, `currencyId`/`exchangeRate` on transactions
- `CurrencyConversionService` exists and is registered
- **No exchange difference posting** when rates change between invoice date and payment date

**Evidence**: No code in `PostingEngine` or `TransactionEngine` that calculates or posts exchange rate differences.

**Impact**: Multi-currency transactions will have incorrect GL balances if rates fluctuate.

---

## 4. Medium Priority Findings

### M1. DEAD TABLE: `ItemVariants`

**Severity**: MEDIUM  
**Location**: `app_database.dart`  
**Description**: The `ItemVariants` table extends `SyncableTable` but defines NO additional columns.

```dart
class ItemVariants extends Table with SyncableTable {
  @override
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

**Impact**: Zero utility. Should have `productId`, `attributeName`, `attributeValue` columns.

### M2. MISSING DAO METHODS FOR PAYMENT LINKS

**Severity**: MEDIUM  
**Location**: `sales_dao.dart`, `purchases_dao.dart`  
**Description**: 
- `CustomerPaymentLinks` table exists — links customer payments to specific sales
- `PurchasePaymentLinks` table exists — links supplier payments to specific purchases
- NEITHER table has DAO methods to read/write them
- Customer payments don't link to specific invoices

**Impact**: Can't track partial payments per invoice. Payment allocation is non-functional.

### M3. `CustomerPayments` TABLE LACKS KEY FIELDS

**Severity**: MEDIUM  
**Location**: `app_database.dart` (CustomerPayments table)  
**Description**: Missing critical columns:
- No `paymentMethod` column (cash/bank/check)
- No `referenceNumber` column
- No `accountId` (GL account) column

```dart
class CustomerPayments extends Table with SyncableTable {
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get amount => text().map(const DecimalConverter())();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable();
  // MISSING: paymentMethod, referenceNumber, accountId, status
}
```

**Impact**: Cannot properly reconcile customer payments or generate payment reports.

### M4. `SupplierPayments` MISSING `paymentMethod`

**Severity**: MEDIUM  
**Location**: `app_database.dart` (SupplierPayments table)  
**Description**: Similar to M3 — no `paymentMethod` column, though it has `status` and `remainingAmount`.

### M5. SALES/PURCHASE HISTORY PAGES DON'T SHOW ACCOUNTING STATUS

**Severity**: MEDIUM  
**Location**: `sales_history_page.dart`, `purchases_page.dart`  
**Description**: 
- Sales history shows status (draft/posted) but no link to journal entry
- No "View Journal Entry" action
- Purchase details no posting date shown

**Impact**: Users can't trace transactions to their GL impact from the transaction list.

### M6. PROMOTIONS/PRICE LISTS NOT INTEGRATED WITH POS

**Severity**: MEDIUM  
**Location**: `pos_bloc.dart`, `pricing_service.dart`  
**Description**: 
- `PromotionsPage` and `PriceLists` UI exist
- `PricingService` has price calculation methods
- Promotions and price lists are NOT consulted during POS checkout in `PosBloc`

**Evidence**: 
- `PosBloc` sets prices from product data directly
- `PricingService` is injected into `PosBloc` but `getPromotionalPrice()` is never called in the checkout flow

**Impact**: Promotions and price lists are decorative — they don't affect transaction prices.

---

## 5. Low Priority Findings

### L1. 15+ SERVICES REGISTERED BUT NEVER USED

**Severity**: LOW  
**Location**: `injection_container.dart`, all DI modules  
**Description**: Services registered in GetIt but never referenced in any presenter/UI code:

| Service | Registered In | Usage |
|---------|--------------|-------|
| `EcommerceIntegrationService` | sales_module | None |
| `ConflictResolver` | core_module | None |
| `DataImportService` | core_module | None |
| `ReorderService` | inventory_module | None |
| `CommunicationService` | injection_container | None |
| `DrvieBackupService` | injection_container | None (Google Drive backup) |
| `SystemAuditor` | injection_container | None |
| `ErpDataService` | injection_container | None |
| `FastAccessService` | injection_container | None (but provided as ChangeNotifier) |
| `CacheService` | injection_container | None |
| `PaginatedQuery` | injection_container | None |
| `MultiLevelApprovalService` | injection_container | None |
| `AnalyticsService` | injection_container | None |
| `InventoryAuditService` | injection_container | None |
| `ReportEngineService` | injection_container | None |

**Impact**: Dead code increases binary size and cognitive load.

### L2. `SalesDao.watchTotalProfitToday()` USES DOUBLE

**Severity**: LOW  
**Location**: `sales_dao.dart:48-55`  
**Description**: Financial calculation uses `double` instead of `Decimal`:

```dart
profit += ((item.price - product.buyPrice) * item.quantity).toDouble();
```

**Impact**: Potential floating-point rounding errors in profit calculations.

### L3. DUPLICATE STOCK TRANSFER PATHS

**Severity**: LOW  
**Location**: `ProductsDao.transferStock()` vs `TransactionEngine`  
**Description**: 
- `ProductsDao.transferStock()` handles stock transfer with batch management
- `TransactionEngine` or `StockTransferService` has separate implementation
- Two different implementations with different validation rules

### L4. NO RESTORE VALIDATION

**Severity**: LOW  
**Location**: `backup_service.dart`  
**Description**: 
- Backup creation exists
- Restore copies file but doesn't validate:
  - File integrity (checksum)
  - Schema version compatibility
  - Encryption key compatibility
  - Data consistency

### L5. NO SERIAL NUMBER TRACKING IN SALES/PURCHASES UI

**Severity**: LOW  
**Location**: `sales_invoice_page.dart`, `add_purchase_page.dart`  
**Description**: 
- `SerialNumbersPage` and `SerialNumberService` exist
- Serial numbers are NOT collected during sale/purchase item entry
- No way to track which serial number was sold to which customer

---

## 6. Database Schema Issues

### D1. MISSING `ON DELETE CASCADE`

**Severity**: MEDIUM  
**Location**: All table definitions  
**Description**: Almost all foreign key references are defined without cascade delete. While DAOs handle deletion manually, direct database operations or future changes could orphan records.

**Example (current)**:
```dart
TextColumn get saleId => text().references(Sales, #id)();
```
**Should be**:
```dart
TextColumn get saleId => text().references(Sales, #id(), onDelete: ReferenceAction.cascade)();
```

**Affected tables**: All FK relationships across 50+ tables.

### D2. `GLEntries.referenceType` SHOULD BE ENUM

**Severity**: LOW  
**Location**: `app_database.dart` (GLEntries table)  
**Description**: `referenceType` is `text().nullable()` — allows any string:
```dart
TextColumn get referenceType => text().nullable();
```

Should use a `TypeConverter` like `DocumentStatusConverter` to enforce valid values.

### D3. `GLEntries.status` INCONSISTENT WITH OTHER TABLES

**Severity**: LOW  
**Location**: `app_database.dart` (GLEntries table)  
**Description**: 
- `Sales.status` uses `DocumentStatus` enum converter
- `Purchases.status` uses `DocumentStatus` enum converter
- `GLEntries.status` uses raw string `'DRAFT'` / `'POSTED'` / `'CANCELLED'`

**Impact**: Inconsistent approach — should use shared enum for status across all document types.

---

## 7. Security Issues

### S1. PERMISSION GUARD NOT APPLIED TO ALL SCREENS

**Severity**: MEDIUM  
**Location**: Multiple workspace/settings screens  
**Description**: 
- `AccessGuard` and `PermissionGuard` exist and are used on core transaction screens
- Workspace pages (Operations, Accounting, Inventory, etc.) don't check permissions
- Settings pages (backup, system settings) lack permission checks

**Impact**: Users with basic access can reach sensitive configuration pages.

### S2. AUDIT LOG DOESN'T CAPTURE ALL STATE CHANGES

**Severity**: MEDIUM  
**Location**: Multiple DAOs and services  
**Description**: Some direct database writes bypass `AuditService.log()`:
- Direct `update()` calls in some DAOs
- Batch operations
- Stock adjustment operations

### S3. NO READ-ONLY USER ROLE

**Severity**: LOW  
**Location**: `user_role.dart`  
**Description**: Only three roles exist:
- `Admin` — full access
- `Manager` — operational access
- `Cashier` — limited POS access

Missing: auditor/report-only role with read access to all data but no write capability.

---

## 8. Performance Issues

### P1. `SalesDao.watchTotalProfitToday()` N+1 AND DOUBLE USAGE

**Severity**: MEDIUM  
**Location**: `sales_dao.dart:32-55`  
**Description**: The stream query:
1. Joins sale_items + sales + products (correct)
2. Converts to `double` for profit calculation
3. Recalculates on EVERY change to sales/items/products

### P2. `AccountingDao.getAccountBalance()` IN-MEMORY AGGREGATION

**Severity**: MEDIUM  
**Location**: `accounting_dao.dart:187-206`  
**Description**: Loads ALL transactions for an account into Dart, then sums:
```dart
final rows = await query.get();
// ... iterate in Dart to sum
```
Should use SQL `SUM()` expression.

### P3. MISSING `LIMIT` ON STREAM QUERIES

**Severity**: LOW  
**Location**: `sales_dao.dart`, `purchases_dao.dart`  
**Description**: `watchAllSales()` and `watchAllPurchases()` have no limit. As data grows, these streams will degrade performance.

---

## 9. Test Coverage Gaps

| Area | Files Found | Coverage | 
|------|-------------|----------|
| **Accounting Posting** | ❌ None | **0%** |
| **Full ERP Cycle** | ❌ None | **0%** |
| **Multi-currency** | ❌ None | **0%** |
| **Period Closing** | ❌ None | **0%** |
| **Inventory Valuation** | 1 file (390 lines) | Partial (AVCO/FIFO math only) |
| **Budget Control** | ❌ None | **0%** |
| **Payment Allocation** | ❌ None | **0%** |
| **Purchase→GRN Flow** | ❌ None | **0%** |
| **Sales→Return→Refund** | ❌ None | **0%** |
| **Widget Tests** | 3 files | POS, Login, Dashboard |
| **Integration Tests** | 7 files | DB init, workflow, performance |
| **Unit Tests** | 12 files | Enums, validators, calculators, auth |

### Existing Test Files Inventory

| File | Lines | What It Tests |
|------|-------|---------------|
| `test/logic/validators_test.dart` | 406 | Sales, Purchase, Inventory, Accounting validators |
| `test/services/inventory_costing_test.dart` | 390 | AVCO/FIFO/LIFO calculator logic |
| `test/logic/calculation_test.dart` | 295 | Tax, Discount, Invoice calculations |
| `test/integration/database_init_test.dart` | 179 | Table creation, indexes, seed data |
| `test/services/pricing_service_test.dart` | 177 | Pricing tiers, discounts, promotions |
| `test/services/post_development_test.dart` | 175 | Backup, VAT, P&L, data validation |
| `test/integration/sales_workflow_test.dart` | 223 | Sales/purchase/payment/return/transfer workflows |
| `test/integration/comprehensive_workflow_test.dart` | 193 | Multi-item sales/purchases/tax/profit |
| `test/widgets/dashboard_page_test.dart` | 245 | Dashboard stats rendering |
| `test/widgets/pos_page_test.dart` | 207 | POS widget rendering |
| `test/services/accounting_service_test.dart` | 209 | Account codes, journal balance, ratios, VAT |
| `test/logic/unit_conversion_test.dart` | 151 | Unit conversion logic |
| `test/logic/auth_test.dart` | 115 | UserRole permissions |

---

## 10. Complete Fix Plan (Priority-Ordered)

### Phase 1: Critical (Immediate)

| # | Fix | Files | Effort |
|---|-----|-------|--------|
| 1 | Add accounting posting integration tests | `test/integration/accounting_posting_test.dart` | 2h |
| 2 | Add full accounting cycle integration test | `test/integration/accounting_cycle_test.dart` | 3h |
| 3 | Add period status indicator to transaction pages | `sales_invoice_page.dart`, `add_purchase_page.dart` | 2h |

### Phase 2: High (This Week)

| # | Fix | Files | Effort |
|---|-----|-------|--------|
| 4 | Add missing DB indexes | `app_database.dart` | 1h |
| 5 | Fix warehouse-level stock tracking | `transaction_engine.dart` | 3h |
| 6 | Wire budget control to transactions | `transaction_engine.dart` | 2h |
| 7 | Consolidate purchase posting paths | `purchase_service.dart`, `transaction_engine.dart` | 2h |
| 8 | Add exchange difference posting | `posting_engine.dart` | 3h |
| 9 | Add accounting cycle integration test | `test/integration/accounting_cycle_test.dart` | 3h |

### Phase 3: Medium (This Sprint)

| # | Fix | Files | Effort |
|---|-----|-------|--------|
| 10 | Fix `ItemVariants` dead table | `app_database.dart`, migration | 1h |
| 11 | Add payment link DAO methods | `sales_dao.dart`, `purchases_dao.dart` | 2h |
| 12 | Add missing fields to CustomerPayments | `app_database.dart`, migration | 1h |
| 13 | Link sales/purchase history to GL | `sales_history_page.dart`, `purchases_page.dart` | 2h |
| 14 | Wire promotions/price lists to POS | `pos_bloc.dart`, `pricing_service.dart` | 3h |

### Phase 4: Low (Backlog)

| # | Fix | Files | Effort |
|---|-----|-------|--------|
| 15 | Remove/consolidate dead services | DI modules | 2h |
| 16 | Fix double usage to Decimal | `sales_dao.dart` | 1h |
| 17 | Add restore validation | `backup_service.dart` | 2h |
| 18 | Add serial number tracking in sales UI | `sales_invoice_page.dart` | 3h |

---

## Appendix: Complete File Inventory

### Core Services (80+ files)
```
lib/core/services/
├── accounting_period_service.dart
├── accounting_service.dart
├── advanced_permission_service.dart
├── aging_service.dart
├── analytics_service.dart
├── app_config_service.dart
├── app_settings_service.dart
├── approval_workflow_service.dart
├── asset_service.dart
├── attendance_service.dart
├── audit_log_service.dart
├── audit_service.dart
├── auto_break_service.dart
├── backup/backup_service.dart
├── bank_reconciliation_service.dart
├── barcode_generation_service.dart
├── barcode_scanner_service.dart
├── bom_service.dart
├── budget_service.dart
├── cash_management_service.dart
├── chart_of_accounts_service.dart
├── chart_service.dart
├── communication_service.dart
├── conflict_resolver.dart
├── credit_note_service.dart
├── currency_conversion_service.dart
├── currency_service.dart
├── dashboard_service.dart
├── data_import_service.dart
├── delivery_notes_service.dart
├── depreciation_service.dart
├── ecommerce_integration_service.dart
├── eosb_service.dart
├── erp_data_service.dart
├── event_bus_service.dart
├── fast_access_service.dart
├── financial_closing_service.dart
├── financial_control_service.dart
├── financial_report_service.dart
├── fixed_assets_service.dart
├── grn_service.dart
├── hr_service.dart
├── inventory_audit_service.dart
├── inventory_costing_service.dart
├── inventory_report_service.dart
├── inventory_reservation_service.dart
├── inventory_service.dart
├── invoice_service.dart
├── journal_service.dart
├── leave_management_service.dart
├── loyalty_service.dart
├── multi_level_approval_service.dart
├── notification_service.dart
├── packaging_engine.dart
├── payroll_service.dart
├── pdf_service.dart
├── permission_service.dart
├── posting_engine.dart
├── pricing_service.dart
├── proforma_service.dart
├── production_service.dart
├── product_image_service.dart
├── profitability_service.dart
├── purchase_converter.dart
├── purchase_service.dart
├── quick_customer_service.dart
├── reconciliation_service.dart
├── recurring_entry_service.dart
├── reorder_service.dart
├── report_engine_service.dart
├── return_service.dart
├── sales_commission_service.dart
├── sales_order_service.dart
├── sales_service.dart
├── security_service.dart
├── serial_number_service.dart
├── shift_service.dart
├── statement_printing_service.dart
├── statement_service.dart
├── stock_operation_service.dart
├── stock_transfer_service.dart
├── supplier_analytics_service.dart
├── system_auditor.dart
├── tax_service.dart
├── thermal_printer_service.dart
├── transaction_engine.dart
├── transfer_service.dart
├── unified_statement_service.dart
├── unit_conversion_service.dart
├── vat_service.dart
├── withholding_tax_service.dart
└── zakat_service.dart
```

### DAOs (16 files)
```
lib/data/datasources/local/daos/
├── accounting_dao.dart (+ .g.dart)
├── audit_dao.dart (+ .g.dart)
├── bom_dao.dart (+ .g.dart)
├── cashbox_dao.dart (+ .g.dart)
├── customers_dao.dart (+ .g.dart)
├── global_units_dao.dart (+ .g.dart)
├── product_units_dao.dart (+ .g.dart)
├── products_dao.dart (+ .g.dart)
├── purchases_dao.dart (+ .g.dart)
├── recurring_entry_dao.dart (+ .g.dart)
├── sales_dao.dart (+ .g.dart)
├── stock_movement_dao.dart (+ .g.dart)
├── suppliers_dao.dart (+ .g.dart)
├── transfers_dao.dart (+ .g.dart)
├── users_dao.dart (+ .g.dart)
└── warehouses_dao.dart (+ .g.dart)
```

### Tables (13 definition files)
```
lib/data/datasources/local/tables/
├── advanced_accounting_tables.dart
├── app_config_table.dart
├── app_settings_table.dart
├── attendance_tables.dart
├── audit_logs_table.dart
├── commission_credit_tables.dart
├── fixed_assets_tables.dart
├── leave_tables.dart
├── payroll_tables.dart
├── proforma_tables.dart
├── security_tables.dart
├── tax_serial_tables.dart
└── zakat_eosb_tables.dart
```

### Routes (103 routes)
- 6 workspace routes
- 4 auth routes
- 7 sales routes (history, invoice, returns, orders, credit notes, commissions, proforma)
- 3 purchase routes (list, add, orders, returns, performance)
- 5 inventory routes (transfer, warehouses, stock-take, beginning, low-stock, manager, shifts, movements)
- 28 accounting routes (COA, GL, balance sheet, income statement, cash flow, trial balance, etc.)
- 25+ report routes
- 9 settings routes
- 5 HR routes
- 2 manufacturing routes

### Test Files (27 files)
```
test/
├── debug_fk_test.dart
├── smoke_test.dart
├── temp_account_check_test.dart
├── integration/
│   ├── comprehensive_workflow_test.dart
│   ├── database_helper_test.dart
│   ├── database_init_test.dart
│   ├── db_performance_test.dart
│   ├── erp_flow_test.dart
│   ├── sales_flow_test.dart
│   └── sales_workflow_test.dart
├── logic/
│   ├── auth_test.dart
│   ├── calculation_test.dart
│   ├── enums_test.dart
│   ├── posting_engine_test.dart
│   ├── unit_conversion_test.dart
│   └── validators_test.dart
├── presentation/
│   ├── pos_addproduct_test.dart
│   └── pos_bloc_test.dart
├── services/
│   ├── accounting_service_test.dart
│   ├── app_config_service_test.dart
│   ├── inventory_costing_test.dart
│   ├── post_development_test.dart
│   └── pricing_service_test.dart
├── unit/
│   ├── access_control_test.dart
│   ├── accounting_service_test.dart
│   ├── analytics_service_test.dart
│   └── inventory_service_test.dart
└── widgets/
    ├── dashboard_page_test.dart
    ├── login_page_test.dart
    └── pos_page_test.dart
```
