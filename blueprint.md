# Blueprint: System Market ERP Completion

## Overview
System Market ERP is a comprehensive enterprise resource planning system for supermarkets, based on the Onyx lectures standards. It covers Accounting, Inventory, Sales, Purchases, and Manufacturing.

## Current State (Phase 1 Audit)
- **Framework:** Flutter (Material 3), Drift (SQLite), Provider.
- **Architecture:** Layered (Presentation, Domain, Data, Core).
- **Audit Findings:**
    - **Stability:** Project build and dependency resolution are stable.
    - **Localization:** System supports AR/EN, but many strings were hardcoded or missing. (Partially fixed).
    - **Accounting:** Core ledger logic is solid, but "Advanced Accounting" features (Budgets, Cost Centers) were partially disconnected from the core.
    - **Cost Centers:** Dual table conflict (`CostCenters` text-id vs `AccCostCenters` int-id).
    - **Manufacturing:** Pages were functional but used hardcoded Arabic strings. (Localized in Phase 1).
    - **Expenses:** Missing cost center link to budgeting. (Fixed in Phase 1).

## Accomplishments (Phase 1)
1. **Stabilization:** Resolved `flutter pub get` and `build_runner` issues.
2. **Localization Fix:** Added missing `noItemsSelected` key and localized `ProductionOrdersPage` and `BomManagementPage`.
3. **Feature Gap:** Improved `ExpensesPage` to allow Cost Center selection, enabling budget validation.
4. **Data Integrity:** Updated `AccountingService.recordExpense` to save `costCenterId` in `GLLines`.
5. **Validation:** All 229 unit/integration tests passed.

## Phase 2: Stabilization & Cleanup (NEXT)
### 1. Architectural Unification
- Consolidate `CostCenters` and `AccCostCenters` into a single robust table with tree support.
- Update all references in `Budgets`, `GLLines`, and `Reports`.

### 2. Security & RBAC
- Implement `UserRolesPage` to manage permissions dynamically.
- Ensure all sensitive operations are guarded by `PermissionService`.

### 3. Financial Integrity
- Implement `Revaluation` logic in `AccountingService`.
- Enhance `Financial Year Closing` with validation and logging.

### 4. UI/UX Polishing
- Finish localization for all settings and report pages.
- Standardize error handling and snackbar feedback across all features.

## Phase 3: Enterprise Readiness
- Advanced Reports (Aging, Cash Flow Forecast).
- Inventory Costing (FIFO/FEFO) deep validation.
- Cloud Sync & Backup Integrity checks.
