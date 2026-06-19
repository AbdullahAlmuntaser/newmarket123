# Blueprint: System Market ERP Completion

## Overview
System Market ERP is a comprehensive enterprise resource planning system for supermarkets, based on the Onyx lectures standards. It covers Accounting, Inventory, Sales, Purchases, and Manufacturing.

## Current State
- **Framework:** Flutter (Material 3), Drift (SQLite), Provider/BLoC.
- **Architecture:** Layered (Presentation, Domain, Data, Core).
- **Core Stability:** Project is stable, static analysis is clean, and basic database restoration is complete.

## Implementation Plan: All Remaining Phases

### Phase 1: Data Integrity & Financial Accuracy
- **Decimal Unification:** Migrate all financial `RealColumn` (double) fields to `Decimal` (String-mapped) to ensure absolute precision.
  - Tables: `StockTakeItems`, `GoodReceivedNoteItems`, `DeliveryNoteItems`, `PurchaseOrders`, `SalesOrders`, `Checks`, `InvoiceItems`, `CreditNoteItems`.
- **Currency Unification:** Merge `Currencies` and `AccCurrencies`. Standardize on `Currencies` table using code-based keys.
- **Migration Logic:** Implement robust `onUpgrade` logic for schema version 42.

### Phase 2: Security & Governance
- **SQLCipher Integration:** Implement transparent database encryption using `sqlcipher_flutter_libs`.
- **RBAC (Role-Based Access Control):** 
  - Implement `PermissionService` to guard all sensitive operations.
  - UI for managing role-based permissions.
- **Session & Session Security:**
  - Auto-timeout for inactivity.
  - Secure storage for authentication tokens using `FlutterSecureStorage`.
- **Password Protection:** Ensure all user passwords use secure `BCrypt` hashing.

### Phase 3: Advanced Business Features
- **Auto-Break Service:** Hierarchical unit management (Pallet -> Carton -> Piece) with automatic stock deduction.
- **Bank Reconciliation:** Import bank statements and match against GL entries with automated logic.
- **Aging Reports:** AR/AP Aging with 30/60/90+ day buckets.
- **POS Returns:** Integrated return mode in POS with automatic credit/refund and stock reversal.

### Phase 4: Performance & Scalability
- **Database Indexing:** Add composite and performance-critical indexes for ERP scale.
- **UI Optimization:**
  - Implement pagination for all large list views (Customers, Products, Invoices).
  - Stream subscription management (Auto-dispose).
- **Caching:** Implement Dashboard and reference data caching.

## Actionable Steps (Current Session)

1. **Step 1: Data Integrity (Decimal & Currencies)**
   - Update `app_database.dart` with `DecimalColumn` for the 8 target tables.
   - Implement `migrateCurrencyTables` logic.
   - Run `build_runner` and verify migrations.

2. **Step 2: Security Implementation**
   - Integrate `PermissionService` and `SessionService`.
   - Update `AuthProvider` for secure token management.
   - Configure SQLCipher in database initialization.

3. **Step 3: Feature Development**
   - Create `AutoBreakService`.
   - Implement Bank Reconciliation and Aging Report services and pages.
   - Update POS BLoC for return mode support.

4. **Step 4: Performance Tuning**
   - Apply missing indexes via migration.
   - Refactor list views for pagination.
   - Implement dashboard caching.

5. **Step 5: Final Validation**
   - Run full test suite.
   - Perform static analysis.
   - Verify visual integrity and performance on large datasets.
