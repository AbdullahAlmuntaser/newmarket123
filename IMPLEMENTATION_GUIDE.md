# ERP/POS CRITICAL FIX EXECUTION — IMPLEMENTATION GUIDE

## Code Changes Already Applied (In Codebase)

| Fix | File | Change |
|-----|------|--------|
| A. COGS | `accounting_dao.dart` | `getIncomeStatement` now reads COGS account balance instead of hardcoding `Decimal.zero`; `grossProfit = totalRevenue - costOfGoodsSold`; `netIncome` excludes COGS |
| B. Revaluation | `accounting_service.dart` | `createRevaluationEntry` now creates real debit/credit entries with computed differences; supports explicit override parameters |
| D. Decimal | `accounting_dao.dart` | All 6 `CAST(... AS REAL)` replaced with Dart-side Decimal aggregation; `getAccountBalance`, `getAccountBalanceAsOfDate`, `getAccountBalanceInRange`, `getTrialBalance`, `getAllAccountBalancesAsOfDate`, `getExpensesByCostCenter` |
| D. Decimal | `accounting_service.dart` | Removed redundant `Decimal.parse(... .toString())` wrappers; `getFinancialRatios` passes Decimal directly |
| D. Decimal | `budget_service.dart` | Changed `expenseAmount` from `double` to `Decimal` in both `validateExpenseAgainstBudget` and `updateActualBudget` |
| D. Decimal | `accounting_service.dart` | `recordExpense` passes `Decimal` directly instead of `.toDouble()` |

---

# SECTION A: COGS — COMPLETE IMPLEMENTATION DETAIL

## Files To Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/data/datasources/local/daos/accounting_dao.dart` | ✅ Done — `getIncomeStatement` reads COGS (account 5010) |
| 2 | `lib/core/services/accounting_service.dart` | ✅ Done — redundant Decimal.parse removed |
| 3 | `lib/core/services/inventory_costing_service.dart` | Enhancement: add `calculateCogsForDateRange` method |
| 4 | `lib/core/services/transaction_engine.dart` | Enhancement: post COGS as part of sale posting (already does via `saleCogs`) |

## Classes Modified
- `AccountingDao` — `getIncomeStatement()`
- `IncomeStatement` — now returns correct `costOfGoodsSold` and `grossProfit`

## Test Cases
1. **COGS Calculation**: Create a purchase (10 units @ $10). Create a sale (5 units). Verify COGS = $50, grossProfit = revenue - $50.
2. **Income Statement**: Run `getIncomeStatement` with date range. Verify `costOfGoodsSold > 0` when sales exist.
3. **Edge: No COGS account**: If account 5010 doesn't exist, COGS = 0 (fallback safe).
4. **Edge: Full returns**: If all sold items are returned, COGS should reverse.
5. **Multi-batch**: Sell 15 units from batches of 10 @ $10 and 10 @ $12. FIFO COGS = 10×$10 + 5×$12 = $160.

## Risk Assessment
- **Low risk**: The COGS account (5010) already exists in `AccountingService.seedDefaultAccounts()`.
- **Performance**: N+1 on COGS query — mitigated by `getAllAccountBalancesAsOfDate` which now does a single query.

---

# SECTION B: ASSET REVALUATION — COMPLETE IMPLEMENTATION DETAIL

## Files To Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/core/services/accounting_service.dart` | ✅ Done — `createRevaluationEntry` now balanced with real amounts |

## Classes Modified
- `AccountingService` — `createRevaluationEntry()` signature changed: now accepts optional `debitAccountId`, `creditAccountId`, `amount`

## Migration Scripts
None needed — only logic change.

## Code Sample (How to call)
```dart
// Automatic revaluation (requires invoice.previousValue, invoice.newValue)
await accountingService.createRevaluationEntry(invoice, 'Annual revaluation');

// Explicit revaluation
await accountingService.createRevaluationEntry(
  invoice,
  'Asset write-down',
  debitAccountId: retainedEarningsId,
  creditAccountId: assetAccountId,
  amount: Decimal.parse('5000.00'),
);
```

## Test Cases
1. **Value increase**: previousValue=1000, newValue=1500 → Debit asset $500, Credit retained earnings $500
2. **Value decrease**: previousValue=1500, newValue=1000 → Debit retained earnings $500, Credit asset $500
3. **No change**: previousValue=newValue → throws Exception("لا يوجد فرق في القيمة لإعادة التقييم")
4. **Explicit params**: debitAccountId/creditAccountId/amount used directly regardless of invoice values

## Risk Assessment
- **Low risk**: Only affects the revaluation flow; existing callers must be checked to ensure they handle the updated signature.

---

# SECTION C: CURRENCY UNIFICATION — COMPLETE IMPLEMENTATION DETAIL

## Files To Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/data/datasources/local/tables/advanced_accounting_tables.dart` | Remove `AccCurrencies` table; update `AccExchangeRates` to reference `Currencies.code` |
| 2 | `lib/data/datasources/local/app_database.dart` | Remove `AccCurrencies` from table list; add migration step |
| 3 | `lib/data/datasources/local/app_database.g.dart` | Regenerate after schema change |
| 4 | Any DAO referencing `AccCurrencies` | Update to use `Currencies` |

## Database Changes

### Current State
```dart
// Currencies — primary table, used by Customers, Sales, Purchases
class Currencies extends Table with SyncableTable {
  TextColumn get code => text().unique()(); // YER, SAR, USD
  TextColumn get name => text()();
  TextColumn get fractionalUnit => text().nullable()();
  IntColumn get decimalPlaces => integer().withDefault(Constant(2))();
  TextColumn get exchangeRate => text().map(DecimalConverter)().withDefault(Decimal.one);
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
}

// AccCurrencies — duplicate, used only by AccExchangeRates
class AccCurrencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 3, max: 3)();
  TextColumn get name => text().withLength(min: 2, max: 50)();
  TextColumn get exchangeRate => text().map(DecimalConverter)().withDefault(Decimal.one);
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

### Target State
- `AccCurrencies` removed
- `AccExchangeRates` references `Currencies.code` (text) instead of `AccCurrencies.id` (int)

## Migration Script (Version 40)
```dart
// In AppDatabase.migration, add to version 40:
await m(callback) {
  // Step 1: Copy any AccCurrencies data that doesn't exist in Currencies
  await customStatement('''
    INSERT OR IGNORE INTO currencies (id, code, name, exchange_rate, is_base, created_at, updated_at)
    SELECT 'ACC-' || ac.id, ac.code, ac.name, ac.exchange_rate, ac.is_base, ac.created_at, datetime('now')
    FROM acc_currencies ac
  ''');

  // Step 2: Update AccExchangeRates to use currency codes instead of IDs
  // Add temp columns
  await customStatement('ALTER TABLE acc_exchange_rates ADD COLUMN from_currency_code TEXT');
  await customStatement('ALTER TABLE acc_exchange_rates ADD COLUMN to_currency_code TEXT');
  
  // Populate temp columns
  await customStatement('''
    UPDATE acc_exchange_rates 
    SET from_currency_code = (SELECT code FROM acc_currencies WHERE id = from_currency_id),
        to_currency_code = (SELECT code FROM acc_currencies WHERE id = to_currency_id)
  ''');

  // Drop old FK columns
  await customStatement('ALTER TABLE acc_exchange_rates DROP COLUMN from_currency_id');
  await customStatement('ALTER TABLE acc_exchange_rates DROP COLUMN to_currency_id');
  
  // Rename temp columns (SQLite doesn't support RENAME COLUMN in older versions, but drift uses >=3.25)
  await customStatement('ALTER TABLE acc_exchange_rates RENAME COLUMN from_currency_code TO from_currency_id');
  await customStatement('ALTER TABLE acc_exchange_rates RENAME COLUMN to_currency_code TO to_currency_id');

  // Step 3: Drop AccCurrencies table
  await customStatement('DROP TABLE IF EXISTS acc_currencies');
}
```

## Risk Assessment
- **HIGH**: Schema migration is irreversible (DROP TABLE). Must backup before deploying.
- Ensure no code references `AccCurrencies` directly (the grep showed no business logic references).
- Test on a copy of production data first.

---

# SECTION D: DECIMAL CONVERSION — REMAINING FILES

## Already Fixed In Codebase
- `accounting_dao.dart` — all 6 `CAST(... AS REAL)` → Dart Decimal aggregation
- `accounting_service.dart` — removed Decimal.parse wrappers
- `budget_service.dart` — `expenseAmount` now `Decimal` not `double`

## Remaining Files To Fix

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `app_database.dart` | `APInvoices.totalAmount` is `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 2 | `app_database.dart` | `StockTakeItems.expectedQuantity`, `.actualQuantity` are `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 3 | `app_database.dart` | `GoodReceivedNoteItems.receivedQuantity`, `.orderedQuantity` are `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 4 | `app_database.dart` | `DeliveryNoteItems.deliveredQuantity`, `.orderedQuantity` are `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 5 | `app_database.dart` | `PurchaseOrders.subtotal`, `.taxAmount`, `.totalAmount` are `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 6 | `app_database.dart` | `SalesOrders.subtotal`, `.taxAmount`, `.totalAmount` are `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 7 | `app_database.dart` | `Checks.amount` is `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 8 | `app_database.dart` | `InvoiceItems.quantity`, `.unitPrice`, `.subtotal` are `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 9 | `app_database.dart` | `CreditNoteItems.quantity`, `.unitPrice`, `.subtotal` are `RealColumn` | Change to `text().map(DecimalConverter)()` |
| 10 | `stock_take_page.dart` | Uses `double` for quantities | Change to `Decimal` |

## Migration Script (For Each Table)
```dart
// For APInvoices.totalAmount:
await customStatement('''
  ALTER TABLE ap_invoices ADD COLUMN total_amount_text TEXT;
  UPDATE ap_invoices SET total_amount_text = CAST(total_amount AS TEXT);
  ALTER TABLE ap_invoices DROP COLUMN total_amount;
  ALTER TABLE ap_invoices RENAME COLUMN total_amount_text TO total_amount;
''');
```

## Risk Assessment
- **HIGH**: Every schema change involving dropping/renaming columns requires careful migration.
- The existing `RealColumn` values are imprecise doubles. Converting them to Decimal text via `CAST(total_amount AS TEXT)` preserves the imprecise value. A one-time cleanup script should round to 4 decimal places after conversion.
- All 9 tables must be done together in a single schema version to avoid inconsistency.

---

# SECTION E: AUTO BREAK — PROFESSIONAL PACKAGING

## Current State
`packaging_engine.dart` has basic auto-break but:
- Does not delegate unit conversion to `UnitConversionService`
- `_breakOnePackage` creates new batches without GL impact
- No cost reallocation logic
- Multi-level break is O(n²) with redundant checks

## Target Design

### Packaging Hierarchy
```
Pallet (1 Pallet = 48 Cartons = 576 Boxes = 13824 Pieces)
  ↓                    ↓                      ↓
Carton (1 Carton = 12 Boxes = 288 Pieces)  [PackagingEngine.breakDown()]
  ↓                    ↓
Box (1 Box = 24 Pieces)
  ↓
Piece (Base Unit)  [UnitConversionService.convertToBase()]
```

### Files To Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/core/services/packaging_engine.dart` | Full rewrite — proper multi-level break, GL integration, cost allocation |
| 2 | `lib/core/services/unit_conversion_service.dart` | Add graph-based conversion (BFS between any two units) |
| 3 | `lib/core/services/inventory_costing_service.dart` | Add `recalculateBatchCostAfterBreak` method |
| 4 | `lib/core/services/transaction_engine.dart` | Wire packaging break to costing service |

### New PackagingEngine Implementation

```dart
class BreakResult {
  final String sourceBatchId;
  final String? targetBatchId;
  final Decimal brokenQuantity;
  final Decimal costPerUnit;
  final List<String> newBatchIds;

  BreakResult({
    required this.sourceBatchId,
    this.targetBatchId,
    required this.brokenQuantity,
    required this.costPerUnit,
    this.newBatchIds = const [],
  });
}

class PackagingEngine {
  final AppDatabase db;
  final InventoryCostingService? costingService;

  PackagingEngine(this.db, {this.costingService});

  Future<List<BreakResult>> autoBreakIfNecessary({
    required String productId,
    required String warehouseId,
    required Decimal requiredQtyInBase,
  }) async {
    final results = <BreakResult>[];
    if (requiredQtyInBase <= Decimal.zero) return results;

    final hierarchy = await _getPackagingHierarchy(productId);
    if (hierarchy.isEmpty) return results;

    // Check available stock across all batch/unit combinations
    Decimal availableBaseQty = await _getAvailableQuantity(productId, warehouseId);
    if (availableBaseQty >= requiredQtyInBase) return results; // No break needed

    Decimal shortfall = requiredQtyInBase - availableBaseQty;

    // Try breaking larger packages level by level
    final sortedDesc = hierarchy
        .where((u) => u.unitFactor > Decimal.one)
        .toList()
      ..sort((a, b) => b.unitFactor.compareTo(a.unitFactor));

    for (final unit in sortedDesc) {
      if (shortfall <= Decimal.zero) break;

      final batches = await _getBatchesHavingAtLeast(
        productId, warehouseId, unit.unitFactor);

      for (final batch in batches) {
        if (shortfall <= Decimal.zero) break;
        if (batch.quantity < unit.unitFactor) continue;

        // Break one package at a time
        while (batch.quantity >= unit.unitFactor && shortfall > Decimal.zero) {
          final result = await _breakOnePackage(
            batch: batch,
            packageFactor: unit.unitFactor,
            productId: productId,
            warehouseId: warehouseId,
          );
          results.add(result);
          shortfall -= unit.unitFactor;
        }
      }
    }

    // Post GL entries for the break operation
    if (results.isNotEmpty) {
      await _postPackagingBreakGL(results, productId);
    }

    return results;
  }

  Future<BreakResult> _breakOnePackage({
    required ProductBatch batch,
    required Decimal packageFactor,
    required String productId,
    required String warehouseId,
  }) async {
    final openedQty = packageFactor;

    // Deduct from source batch
    await (db.update(db.productBatches)..where((b) => b.id.equals(batch.id)))
        .write(ProductBatchesCompanion(
          quantity: Value(batch.quantity - openedQty),
        ));

    // Create broken batch at base unit level
    final newBatchId = const Uuid().v4();
    final costPerUnit = batch.costPrice / packageFactor;
    
    await db.into(db.productBatches).insert(ProductBatchesCompanion.insert(
      id: Value(newBatchId),
      productId: productId,
      warehouseId: warehouseId,
      batchNumber: 'BROKEN-${batch.batchNumber}-${DateTime.now().millisecondsSinceEpoch}',
      quantity: Value(openedQty),
      initialQuantity: Value(openedQty),
      costPrice: Value(costPerUnit),
      expiryDate: Value(batch.expiryDate),
    ));

    // Record transaction
    await db.into(db.inventoryTransactions).insert(
      InventoryTransactionsCompanion.insert(
        productId: productId,
        warehouseId: warehouseId,
        batchId: Value(newBatchId),
        quantity: Value(openedQty),
        type: 'PACKAGE_BREAK',
        referenceId: Value('BREAK-${batch.id}'),
      ),
    );

    developer.log(
      'Auto-broke batch ${batch.batchNumber}: $openedQty units @ $costPerUnit each',
      name: 'packaging_engine',
    );

    return BreakResult(
      sourceBatchId: batch.id,
      targetBatchId: newBatchId,
      brokenQuantity: openedQty,
      costPerUnit: costPerUnit,
    );
  }

  Future<Decimal> _getAvailableQuantity(String productId, String warehouseId) async {
    final batches = await (db.select(db.productBatches)
          ..where((b) => b.productId.equals(productId))
          ..where((b) => b.warehouseId.equals(warehouseId)))
        .get();
    return batches.fold(Decimal.zero, (sum, b) => sum + b.quantity);
  }

  Future<List<ProductBatch>> _getBatchesHavingAtLeast(
    String productId, String warehouseId, Decimal minQty) async {
    return (db.select(db.productBatches)
          ..where((b) => b.productId.equals(productId))
          ..where((b) => b.warehouseId.equals(warehouseId))
          ..where((b) => b.quantity.isBiggerOrEqual(Variable(minQty.toString())))
          ..orderBy([(b) => OrderingTerm(expression: b.expiryDate)]))
        .get();
  }

  Future<void> _postPackagingBreakGL(List<BreakResult> results, String productId) async {
    // Packaging break doesn't change total inventory value
    // so no GL entry is strictly required.
    // However, if costing method is AVCO and unit cost changes, 
    // a revaluation entry may be needed.
    if (costingService != null) {
      final method = await costingService!.getProductValuationMethod(productId);
      if (method == InventoryValuationMethod.avco) {
        // AVCO: After break, recalculate average cost from all remaining batches
        await costingService!.calculateAverageCost(productId);
      }
    }
  }

  Future<List<ProductUnit>> _getPackagingHierarchy(String productId) async {
    return (db.select(db.productUnits)
          ..where((u) => u.productId.equals(productId))
          ..orderBy([(u) => OrderingTerm(expression: u.unitFactor)]))
        .get();
  }
}
```

### UnitConversionService Enhancement (Graph-Based)
```dart
// Add to UnitConversionService:
Future<Decimal> convertBetweenUnits({
  required String productId,
  required Decimal quantity,
  required String fromUnitName,
  required String toUnitName,
}) async {
  if (fromUnitName == toUnitName) return quantity;

  final conversions = await (db.select(db.unitConversions)
        ..where((u) => u.productId.equals(productId)))
      .get();

  // Build adjacency graph
  final graph = <String, Map<String, Decimal>>{};
  for (final conv in conversions) {
    graph.putIfAbsent(conv.unitName, () => {});
    graph[conv.unitName]![ProductUnitsTable.baseUnit] = conv.factor;
  }

  // BFS from fromUnit to toUnit
  final visited = <String>{};
  final queue = <(String, Decimal)>[(fromUnitName, Decimal.one)];
  visited.add(fromUnitName);

  while (queue.isNotEmpty) {
    final (current, factor) = queue.removeAt(0);
    if (current == toUnitName) return quantity * factor;

    for (final entry in (graph[current] ?? <String, Decimal>{}.entries)) {
      if (!visited.contains(entry.key)) {
        visited.add(entry.key);
        queue.add((entry.key, factor * entry.value));
      }
    }
  }

  throw Exception('No conversion path from $fromUnitName to $toUnitName');
}
```

## Test Cases
1. **Single-level break**: 1 Carton (12 pcs) available, need 5 pcs. Should break 1 carton → 12 pcs available.
2. **Multi-level break**: 1 Pallet (48 cartons) available, need 24 pcs. Should break 1 pallet → 48 cartons → 24 pcs from 1 carton.
3. **Sufficient base units**: 100 pcs available, need 5 pcs. No break needed.
4. **Insufficient total stock**: 1 Carton available, need 100 pcs. Should throw insufficient stock.
5. **Cost per unit after break**: 1 Carton @ $12 cost → broken → 12 pcs @ $1.00 each. Verify batch cost prices.

---

# SECTION F: POSTING PROFILES ENGINE

## Current State
`PostingEngine` already has `_getPostingProfiles()` method and `PostingProfile` table. However:
- Profiles are not editable from UI
- No default profiles exist when none are configured
- The system falls back to hardcoded codes only

## Target

### Files To Modify
| # | File | Change |
|---|------|--------|
| 1 | `lib/core/services/posting_engine.dart` | Add default profile creation on first run |
| 2 | `lib/presentation/features/accounting/` | Add Posting Profiles management page |
| 3 | `lib/injection_container.dart` | Register PostingProfileService |

### New File: Posting Profile Management Page (Feature)

```dart
// lib/presentation/features/accounting/posting_profiles_page.dart
class PostingProfilesPage extends StatefulWidget { ... }

// Key operations:
// - List all profiles by operation type (SALE, PURCHASE, etc.)
// - Edit: change accountId for each account type
// - Enable/disable specific profiles
// - Add new operation types
```

### PostingEngine Enhancement

```dart
// Add to PostingEngine:
Future<void> ensureDefaultProfiles() async {
  final existing = await (db.select(db.postingProfiles)).get();
  if (existing.isNotEmpty) return;

  final defaults = <PostingProfilesCompanion>[
    // Sales posting profile
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'SALE',
      accountType: 'CASH',
      accountCode: '1010',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'SALE',
      accountType: 'RECEIVABLE',
      accountCode: '1030',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'SALE',
      accountType: 'REVENUE',
      accountCode: '4010',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'SALE',
      accountType: 'OUTPUT_VAT',
      accountCode: '2020',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'SALE',
      accountType: 'COGS',
      accountCode: '5010',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'SALE',
      accountType: 'INVENTORY',
      accountCode: '1040',
      isActive: true,
    ),
    // Purchase posting profile
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'PURCHASE',
      accountType: 'INVENTORY',
      accountCode: '1040',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'PURCHASE',
      accountType: 'INPUT_VAT',
      accountCode: '1050',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'PURCHASE',
      accountType: 'PAYABLE',
      accountCode: '2010',
      isActive: true,
    ),
    PostingProfilesCompanion.insert(
      id: const Uuid().v4(),
      operationType: 'PURCHASE',
      accountType: 'CASH',
      accountCode: '1010',
      isActive: true,
    ),
  ];

  for (final profile in defaults) {
    await db.into(db.postingProfiles).insert(profile);
  }
}
```

### UI Integration
- Add "Posting Profiles" menu item under Accounting section
- Show table: Operation Type | Account Type | Account Code | Account Name | Active
- Add edit button → account code picker dialog
- Changes take effect immediately (no restart needed)

## Risk Assessment
- **Low**: The PostingProfiles table already exists. Only adding default seeding + UI.
- After UI edit, ensure all posting methods (`_postSale`, `_postPurchase`, etc.) use the profile lookup (already done).

---

# SECTION G: BANK RECONCILIATION — FULL SYSTEM

## New Files

| # | File | Purpose |
|---|------|---------|
| 1 | `lib/presentation/features/accounting/bank_reconciliation_page.dart` | Main reconciliation UI |
| 2 | `lib/presentation/features/accounting/widgets/reconciliation_dialog.dart` | Match/unmatch dialog |
| 3 | `lib/core/services/reconciliation_service.dart` | Business logic |

## Database Requirements
The `Reconciliations` table already exists in the schema (referenced in `AccountingDao`). Verify its structure:

```dart
// Expected columns (verify in app_database.dart):
class Reconciliations extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(GLAccounts, #id)();
  DateTimeColumn get statementDate => dateTime()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get openingBalance => text().map(DecimalConverter)();
  TextColumn get closingBalance => text().map(DecimalConverter)();
  TextColumn get status => text()(); // DRAFT, IN_PROGRESS, RECONCILED
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get reconciledAt => dateTime().nullable()();
}
```

## ReconciliationService (New File)
```dart
class ReconciliationService {
  final AppDatabase db;

  ReconciliationService(this.db);

  /// Get unreconciled transactions for an account
  Future<List<AccountTransaction>> getUnreconciledTransactions(
    String accountId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final query = db.select(db.accountTransactions)
      ..where((t) => t.accountId.equals(accountId))
      ..where((t) => t.reconciled.equals(false));
    if (from != null) query.where((t) => t.date.isBiggerOrEqual(Variable(from)));
    if (to != null) query.where((t) => t.date.isSmallerOrEqual(Variable(to)));
    return query.get();
  }

  /// Match bank statement line to system transaction
  Future<void> matchTransaction({
    required String reconciliationId,
    required String transactionId,
    required Decimal statementAmount,
    required DateTime statementDate,
    String? reference,
  }) async {
    await db.transaction(() async {
      // Mark transaction as reconciled
      await (db.update(db.accountTransactions)
            ..where((t) => t.id.equals(transactionId)))
          .write(const AccountTransactionsCompanion(reconciled: Value(true)));

      // Add reconciliation detail
      await db.into(db.reconciliationDetails).insert(
        ReconciliationDetailsCompanion.insert(
          reconciliationId: reconciliationId,
          transactionId: transactionId,
          statementAmount: Value(statementAmount),
          statementDate: Value(statementDate),
          reference: Value(reference),
        ),
      );
    });
  }

  /// Unmatch a previously matched transaction
  Future<void> unmatchTransaction(String detailId) async {
    final detail = await (db.select(db.reconciliationDetails)
          ..where((d) => d.id.equals(detailId)))
        .getSingle();
    
    await db.transaction(() async {
      await (db.update(db.accountTransactions)
            ..where((t) => t.id.equals(detail.transactionId)))
          .write(const AccountTransactionsCompanion(reconciled: Value(false)));
      await (db.delete(db.reconciliationDetails)
            ..where((d) => d.id.equals(detailId)))
          .go();
    });
  }

  /// Compute reconciliation summary
  Future<ReconciliationSummary> getSummary(String reconciliationId) async {
    final reconciliation = await (db.select(db.reconciliations)
          ..where((r) => r.id.equals(reconciliationId)))
        .getSingle();
    
    final details = await (db.select(db.reconciliationDetails)
          ..where((d) => d.reconciliationId.equals(reconciliationId)))
        .get();

    Decimal matchedDebits = Decimal.zero;
    Decimal matchedCredits = Decimal.zero;
    for (final detail in details) {
      final tx = await (db.select(db.accountTransactions)
            ..where((t) => t.id.equals(detail.transactionId)))
          .getSingle();
      matchedDebits += tx.debit;
      matchedCredits += tx.credit;
    }

    final unreconciled = await getUnreconciledTransactions(
      reconciliation.accountId,
      from: reconciliation.startDate,
      to: reconciliation.endDate,
    );
    Decimal unmatchedDebits = Decimal.zero;
    Decimal unmatchedCredits = Decimal.zero;
    for (final tx in unreconciled) {
      unmatchedDebits += tx.debit;
      unmatchedCredits += tx.credit;
    }

    final systemBalance = await db.accountingDao.getAccountBalanceAsOfDate(
      reconciliation.accountId, reconciliation.endDate);
    final difference = systemBalance - reconciliation.closingBalance;

    return ReconciliationSummary(
      openingBalance: reconciliation.openingBalance,
      statementClosingBalance: reconciliation.closingBalance,
      systemClosingBalance: systemBalance,
      matchedDebits: matchedDebits,
      matchedCredits: matchedCredits,
      unmatchedDebits: unmatchedDebits,
      unmatchedCredits: unmatchedCredits,
      difference: difference,
    );
  }
}

class ReconciliationSummary {
  final Decimal openingBalance;
  final Decimal statementClosingBalance;
  final Decimal systemClosingBalance;
  final Decimal matchedDebits;
  final Decimal matchedCredits;
  final Decimal unmatchedDebits;
  final Decimal unmatchedCredits;
  final Decimal difference;
  // ... constructor
}
```

## Test Cases
1. **Full match**: All transactions match statement → difference = 0
2. **Partial match**: Some transactions unmatched → difference = unmatched amount
3. **Out of balance**: System total ≠ statement total → difference reported
4. **Unmatch**: Previously matched transaction → system balance reverts
5. **Edge: No transactions**: Empty period → difference = opening + closing

---

# SECTION H: AGING REPORTS

## New Files

| # | File | Purpose |
|---|------|---------|
| 1 | `lib/presentation/features/reports/customer_aging_page.dart` | AR Aging Report |
| 2 | `lib/presentation/features/reports/supplier_aging_page.dart` | AP Aging Report |
| 3 | `lib/core/services/aging_service.dart` | Shared aging logic |

## AgingService (New File)
```dart
class AgingBucket {
  final String label; // "Current", "1-30", "31-60", "61-90", "90+"
  final int minDays;
  final int maxDays;
  final List<AgingItem> items;
  Decimal get total => items.fold(Decimal.zero, (s, i) => s + i.amount);
}

class AgingItem {
  final String id;
  final String documentNumber;
  final DateTime date;
  final DateTime dueDate;
  final Decimal amount;
  final Decimal paid;
  final Decimal balance;
  int get daysOverdue => DateTime.now().difference(dueDate).inDays;
}

class AgingService {
  final AppDatabase db;

  AgingService(this.db);

  Future<List<AgingBucket>> getCustomerAging({
    String? customerId,
    DateTime? asOfDate,
  }) async {
    final date = asOfDate ?? DateTime.now();
    final sales = customerId != null
        ? await (db.select(db.sales)
              ..where((s) => s.customerId.equals(customerId))
              ..where((s) => s.isCredit.equals(true))
              ..where((s) => s.status.equals(DocumentStatus.posted.index)))
            .get()
        : await (db.select(db.sales)
              ..where((s) => s.isCredit.equals(true))
              ..where((s) => s.status.equals(DocumentStatus.posted.index)))
            .get();

    // Build aging buckets
    final buckets = _createBuckets();
    for (final sale in sales) {
      final payments = await (db.select(db.customerPayments)
            ..where((p) => p.customerId.equals(sale.customerId)))
          .get();
      final totalPaid = payments.fold(Decimal.zero, (s, p) => s + p.amount);
      final balance = sale.total - totalPaid;
      if (balance <= Decimal.zero) continue;

      final dueDate = sale.createdAt.add(const Duration(days: 30)); // Default terms
      final daysOverdue = date.difference(dueDate).inDays;

      final item = AgingItem(
        id: sale.id,
        documentNumber: sale.id.substring(0, 8),
        date: sale.createdAt,
        dueDate: dueDate,
        amount: sale.total,
        paid: totalPaid,
        balance: balance,
      );

      _assignToBucket(buckets, item, daysOverdue);
    }

    return buckets;
  }

  Future<List<AgingBucket>> getSupplierAging({
    String? supplierId,
    DateTime? asOfDate,
  }) async {
    final date = asOfDate ?? DateTime.now();
    final purchases = supplierId != null
        ? await (db.select(db.purchases)
              ..where((p) => p.supplierId.equals(supplierId))
              ..where((p) => p.isCredit.equals(true))
              ..where((p) => p.status.equals(DocumentStatus.received.index)))
            .get()
        : await (db.select(db.purchases)
              ..where((p) => p.isCredit.equals(true))
              ..where((p) => p.status.equals(DocumentStatus.received.index)))
            .get();

    final buckets = _createBuckets();
    for (final purchase in purchases) {
      final payments = await (db.select(db.supplierPayments)
            ..where((p) => p.supplierId.equals(purchase.supplierId)))
          .get();
      final totalPaid = payments.fold(Decimal.zero, (s, p) => s + p.amount);
      final balance = purchase.total - totalPaid;
      if (balance <= Decimal.zero) continue;

      final dueDate = purchase.date.add(const Duration(days: 30));
      final daysOverdue = date.difference(dueDate).inDays;

      final item = AgingItem(
        id: purchase.id,
        documentNumber: purchase.id.substring(0, 8),
        date: purchase.date,
        dueDate: dueDate,
        amount: purchase.total,
        paid: totalPaid,
        balance: balance,
      );

      _assignToBucket(buckets, item, daysOverdue);
    }

    return buckets;
  }

  List<AgingBucket> _createBuckets() => [
    AgingBucket('Current', -9999, 0, []),
    AgingBucket('1-30 Days', 1, 30, []),
    AgingBucket('31-60 Days', 31, 60, []),
    AgingBucket('61-90 Days', 61, 90, []),
    AgingBucket('90+ Days', 91, 9999, []),
  ];

  void _assignToBucket(List<AgingBucket> buckets, AgingItem item, int days) {
    for (final bucket in buckets) {
      if (days >= bucket.minDays && days <= bucket.maxDays) {
        bucket.items.add(item);
        return;
      }
    }
    buckets.last.items.add(item); // Fallback to 90+
  }
}
```

## Test Cases
1. **Current**: Invoice created today → "Current" bucket
2. **Overdue 35 days**: Invoice due 35 days ago → "31-60 Days" bucket
3. **Partially paid**: $1000 invoice, $400 paid → $600 in appropriate bucket
4. **Fully paid**: Should not appear in aging
5. **Empty**: No credit sales → all buckets empty

---

# SECTION I: POS RETURNS INTEGRATION

## Files To Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/presentation/features/pos/bloc/pos_event.dart` | Add `ProcessReturnEvent` |
| 2 | `lib/presentation/features/pos/bloc/pos_state.dart` | Add return mode state |
| 3 | `lib/presentation/features/pos/bloc/pos_bloc.dart` | Handle return flow |
| 4 | `lib/presentation/features/pos/pos_page.dart` | Add return mode toggle |
| 5 | `lib/presentation/features/pos/widgets/return_dialog.dart` | New: return dialog |
| 6 | `lib/core/services/transaction_engine.dart` | Verify return posting works |

## New Event & State
```dart
// In pos_event.dart
class ToggleReturnMode extends PosEvent {}
class LookupOriginalSale extends PosEvent {
  final String saleReference;
}
class ProcessReturn extends PosEvent {
  final String originalSaleId;
  final List<ReturnItem> items;
  final String? customerId;
}

class ReturnItem {
  final String productId;
  final String? batchId;
  final Decimal quantity;
  final Decimal unitPrice;
  final String reason;
}

// In pos_state.dart
class PosReturnState {
  final bool isReturnMode;
  final Sale? originalSale;
  final List<SaleItem> originalItems;
  final Decimal totalRefund;
  final List<ReturnItem> returnItems;
}
```

## BLoC Handler
```dart
// In pos_bloc.dart, handle ProcessReturn:
Future<void> _handleProcessReturn(
  ProcessReturn event, Emitter<PosState> emit) async {
  try {
    // Create return record
    final returnId = const Uuid().v4();
    await db.into(db.salesReturns).insert(
      SalesReturnsCompanion.insert(
        id: Value(returnId),
        saleId: event.originalSaleId,
        amountReturned: event.items.fold(
          Decimal.zero,
          (s, i) => s + (i.quantity * i.unitPrice),
        ),
        createdAt: Value(DateTime.now()),
      ),
    );

    for (final item in event.items) {
      await db.into(db.salesReturnItems).insert(
        SalesReturnItemsCompanion.insert(
          salesReturnId: returnId,
          productId: item.productId,
          batchId: Value(item.batchId),
          quantity: item.quantity,
          price: item.unitPrice,
          reason: Value(item.reason),
        ),
      );
    }

    // Process through transaction engine
    await transactionEngine.postSaleReturn(returnId);

    emit(state.copyWith(
      returnSuccess: true,
      message: 'تمت عملية المرتجع بنجاح',
    ));
  } catch (e) {
    emit(state.copyWith(error: e.toString()));
  }
}
```

## Test Cases
1. **Full return**: Return all items from a sale → stock restored, customer balance reversed
2. **Partial return**: Return 2 of 5 items → only those 2 items restored
3. **Return with different price**: Item sold at $15, returned at $12 → difference adjustments
4. **Return from non-existent sale**: Should throw error
5. **Return already processed sale**: Should throw duplicate error

---

# SECTION J: PERFORMANCE FIXES

## Already Fixed
- `accounting_dao.dart` — `getTrialBalance` no longer has N+1 query (single pass through all lines)
- `accounting_dao.dart` — `getAllAccountBalancesAsOfDate` uses single query
- `accounting_dao.dart` — All CAST to REAL removed (no double conversion overhead)

## Remaining Performance Fixes

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `accounting_service.dart` `getDashboardData` | 7-day loop makes 14 queries (7 revenue + 7 expense) | Single query with GROUP BY date |
| 2 | `accounting_service.dart` `getFinancialRatios` | Makes 4 separate N+1 loops for current assets/liabilities | Use `getAllAccountBalancesAsOfDate` once |
| 3 | All list pages | No pagination | Add limit/offset with scroll listeners |
| 4 | Various widgets | Stream subscriptions not cancelled | Audit and fix dispose() methods |
| 5 | `transaction_engine.dart` `getOutstandingSales/ Purchases` | Makes N queries for payments | Use single aggregated query |

## getFinancialRatios Optimization
```dart
// Replace the 4 separate loops with:
Future<void> _optimizedGetFinancialRatios() async {
  final dao = db.accountingDao;
  final asOfDate = DateTime.now();
  
  // Single query: all balances as of date
  final allBalances = await dao.getAllAccountBalancesAsOfDate(asOfDate);
  
  final accountByCode = <String, Decimal>{};
  for (final item in allBalances) {
    accountByCode[item.account.code] = item.netBalance;
  }

  Decimal totalCurrentAssets = 
    (accountByCode['1010'] ?? Decimal.zero) +
    (accountByCode['1020'] ?? Decimal.zero) +
    (accountByCode['1030'] ?? Decimal.zero) +
    (accountByCode['1040'] ?? Decimal.zero);

  Decimal totalCurrentLiabilities =
    (accountByCode['2010'] ?? Decimal.zero) +
    (accountByCode['2020'] ?? Decimal.zero);

  // ... rest of calculation
}
```

## getDashboardData Daily Queries Optimization
```dart
// Single query instead of 14:
Future<List<DailyValue>> _getDailyRevenueAndExpenses(
  DateTime startDate, DateTime endDate) async {
  final rows = await (db.select(db.gLLines).join([
    innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
    innerJoin(db.gLAccounts, db.gLAccounts.id.equalsExp(db.gLLines.accountId)),
  ])
        ..where(db.gLEntries.date.isBetweenValues(startDate, endDate))
        ..where(db.gLAccounts.type.isIn(['REVENUE', 'EXPENSE'])))
      .get();

  final Map<DateTime, Decimal> dailyRevenue = {};
  final Map<DateTime, Decimal> dailyExpenses = {};

  for (final row in rows) {
    final entry = row.readTable(db.gLEntries);
    final line = row.readTable(db.gLLines);
    final account = row.readTable(db.gLAccounts);
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    
    if (account.type == 'REVENUE') {
      dailyRevenue[day] = (dailyRevenue[day] ?? Decimal.zero) + 
        line.credit - line.debit;
    } else {
      dailyExpenses[day] = (dailyExpenses[day] ?? Decimal.zero) + 
        line.debit - line.credit;
    }
  }
  // ... merge into DailyValue list
}
```

## Risk Assessment
- **MEDIUM**: Performance optimizations change query patterns. Must verify results match before/after.
- Add pagination gradually — test with 10K+ record datasets.

---

# SECTION K: SECURITY HARDENING

## Files To Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/core/services/security_service.dart` | Complete rewrite: add auth, session, RBAC |
| 2 | `lib/presentation/providers/auth_provider.dart` | Implement FlutterSecureStorage for tokens |
| 3 | `lib/data/datasources/local/app_database.dart` | Add hashed password column; Add SQLCipher |
| 4 | `lib/core/services/backup_service.dart` | Add backup encryption and validation |
| 5 | `lib/injection_container.dart` | Register new auth services |

## SecurityService Rewrite
```dart
class SecurityService {
  final AppDatabase db;
  static const String _saltPrefix = 'SYS_MARKET_v1';
  
  SecurityService(this.db);

  // ===== PASSWORD HASHING =====
  String hashPassword(String password, String salt) {
    final salted = '$_saltPrefix:$salt:$password';
    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String generateSalt() => const Uuid().v4().substring(0, 16);

  bool verifyPassword(String password, String salt, String hash) {
    return hashPassword(password, salt) == hash;
  }

  // ===== AUTHENTICATION =====
  Future<UserSession?> login(String username, String password) async {
    final user = await (db.select(db.users)
          ..where((u) => u.username.equals(username)))
        .getSingleOrNull();
    if (user == null) return null;

    // In current schema, password is stored as plain-text
    // After migration, it will be hashed
    if (password != user.password) return null;

    final session = UserSession(
      userId: user.id,
      username: user.username,
      role: user.role,
      fullName: user.fullName,
      token: const Uuid().v4(),
      loginAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );

    // Store session
    await db.into(db.userSessions).insert(
      UserSessionsCompanion.insert(
        userId: user.id,
        token: session.token,
        expiresAt: Value(session.expiresAt),
      ),
    );

    return session;
  }

  Future<bool> validateSession(String token) async {
    final session = await (db.select(db.userSessions)
          ..where((s) => s.token.equals(token))
          ..where((s) => s.expiresAt.isBiggerOrEqual(Variable(DateTime.now()))))
        .getSingleOrNull();
    return session != null;
  }

  Future<void> logout(String token) async {
    await (db.delete(db.userSessions)..where((s) => s.token.equals(token))).go();
  }

  // ===== PERMISSION CHECKING =====
  bool hasPermission(String userRole, String requiredRole) {
    final roleHierarchy = ['VIEWER', 'CASHIER', 'MANAGER', 'ADMIN'];
    final userLevel = roleHierarchy.indexOf(userRole);
    final requiredLevel = roleHierarchy.indexOf(requiredRole);
    return userLevel >= requiredLevel;
  }

  void requireRole(String userRole, String requiredRole) {
    if (!hasPermission(userRole, requiredRole)) {
      throw Exception('ليس لديك صلاحية كافية للقيام بهذه العملية');
    }
  }

  // ===== DATA ENCRYPTION =====
  Future<String> getEncryptionKey() async {
    // Use FlutterSecureStorage for key persistence
    const secureStorage = FlutterSecureStorage();
    String? key = await secureStorage.read(key: 'db_encryption_key');
    if (key == null) {
      key = const Uuid().v4().replaceAll('-', '').substring(0, 32);
      await secureStorage.write(key: 'db_encryption_key', value: key);
    }
    return key;
  }

  // ===== BACKUP VALIDATION =====
  Future<bool> validateBackupIntegrity(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      return content.contains('SYS_MARKET_BACKUP_V1');
    } catch (_) {
      return false;
    }
  }

  Future<String> encryptBackup(String plaintext) async {
    final key = await getEncryptionKey();
    // AES encryption (using encrypt package)
    final encrypter = Encrypter(AES(Key.fromUtf8(key)));
    final encrypted = encrypter.encrypt(plaintext);
    return 'SYS_MARKET_BACKUP_V1:${encrypted.base64}';
  }

  Future<String> decryptBackup(String encryptedData) async {
    final key = await getEncryptionKey();
    final encrypter = Encrypter(AES(Key.fromUtf8(key)));
    final withoutHeader = encryptedData.replaceFirst('SYS_MARKET_BACKUP_V1:', '');
    return encrypter.decrypt64(withoutHeader);
  }
}

class UserSession {
  final String userId;
  final String username;
  final String role;
  final String fullName;
  final String token;
  final DateTime loginAt;
  final DateTime expiresAt;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
```

## Database Changes
```dart
// Add to Users table:
TextColumn get passwordHash => text().nullable()(); // SHA-256 hash
TextColumn get passwordSalt => text().nullable()(); // Random salt
// Keep old password column during migration, drop later

// New table:
class UserSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get token => text().unique()();
  DateTimeColumn get loginAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  @override
  Set<Column> get primaryKey => {id};
}
```

## Migration Script
```dart
// Version 41 migration:
await customStatement('''
  ALTER TABLE users ADD COLUMN password_hash TEXT;
  ALTER TABLE users ADD COLUMN password_salt TEXT;
  
  // Migrate existing passwords: wrap each with hash
  UPDATE users SET 
    password_salt = substr(replace(hex(randomblob(16)), 'x', ''), 1, 16),
    password_hash = hex(sha256('SYS_MARKET_v1:' || substr(replace(hex(randomblob(16)), 'x', ''), 1, 16) || ':' || password));
''');

// Create sessions table
await customStatement('''
  CREATE TABLE IF NOT EXISTS user_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    token TEXT UNIQUE NOT NULL,
    login_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1
  );
''');

// Enable SQLCipher
// Note: SQLCipher requires native library linkage. Add to pubspec.yaml:
// sqlcipher_flutter_libs: ^0.6.0
// Then in database initialization:
// final db = await openDatabase(
//   path,
//   password: encryptionKey,
// );
```

## Test Cases
1. **Login success**: Correct username/password → session token returned
2. **Login failure**: Wrong password → null returned
3. **Session validation**: Valid token → true; expired token → false
4. **Password hashing**: Different salts produce different hashes for same password
5. **Permission check**: CASHIER cannot access ADMIN functions
6. **Backup validation**: Valid backup → true; tampered backup → false
7. **Encryption roundtrip**: decrypt(encrypt(data)) == data

---

# DEPLOYMENT ORDER

| Phase | Sections | Duration | Dependencies | Risk |
|-------|----------|----------|--------------|------|
| **1** | A (COGS), B (Revaluation), D (Decimal - DAO only) | 2 days | None | Low — logic-only changes |
| **2** | C (Currency), D (Schema migrations) | 3 days | Phase 1 | HIGH — schema changes |
| **3** | E (Auto Break rewrite) | 4 days | Phase 1, D | Medium — core inventory logic |
| **4** | K (Security — auth & hashing) | 5 days | None | HIGH — security critical |
| **5** | J (Performance — queries) | 3 days | Phase 1 | Medium — must verify results |
| **6** | F (Posting Profiles UI) | 3 days | Phase 1 | Low — UI only |
| **7** | G (Bank Reconciliation) | 5 days | Phase 1, 2 | Medium — new feature |
| **8** | H (Aging Reports) | 3 days | Phase 1 | Low — new report |
| **9** | I (POS Returns) | 4 days | Phase 1, 3 | Medium — POS critical path |
| **10** | K (Security — SQLCipher) | 5 days | Phase 4 | HIGH — encryption affects all data |
| **11** | D (Remaining schema: 9 tables) | 3 days | Phase 2 | HIGH — wide-ranging schema changes |
| **12** | Final integration testing | 5 days | All above | HIGH — full regression |

**Total estimated timeline: 45 days (9 weeks) for a single developer, 25 days (5 weeks) for a team of 3.**

---

# RISK ASSESSMENT SUMMARY

| Risk | Level | Mitigation |
|------|-------|------------|
| Schema migration data loss | **CRITICAL** | Backup before every migration; test on copy first |
| SQLCipher performance | **HIGH** | Benchmark with production data; consider selective encryption |
| Decimal conversion rounding | **HIGH** | Use `Decimal(scale: 4)` for all financial columns; validate with known sums |
| POS return concurrency | **HIGH** | Wrap return flow in SQLite transaction with immediate locking |
| Auto-break infinite loop | **MEDIUM** | Add max iterations guard (max 100 breaks per call) |
| Posting profile misconfiguration | **MEDIUM** | Validate that target accounts exist before saving profile |
| Session token interception | **MEDIUM** | Use HTTPS for network; secure storage for tokens |
| COGS post-dated entries | **LOW** | `getAccountBalanceInRange` handles date range correctly |
| Aging report performance | **LOW** | Add limit to prevent loading 100K+ invoices |
| Backup encryption key loss | **HIGH** | Add key recovery mechanism (security question or escrow) |

---

# PRODUCTION READINESS SCORE

## Before Fixes: 3/10
- ✅ UI works for basic CRUD
- ❌ Financial reports are incorrect (COGS=0)
- ❌ No authentication at all
- ❌ Decimal precision loss in all reports
- ❌ No security (plain-text passwords)
- ❌ No bank reconciliation
- ❌ No aging reports
- ❌ POS returns not integrated
- ❌ Performance: N+1 queries, CAST REAL
- ❌ Duplicate currency tables

## After Phase 1-3 (COGS + Revaluation + Decimal): 5/10
- ✅ Financial reports now correct
- ✅ Asset revaluation works
- ✅ All Decimal precision maintained
- ❌ No auth yet
- ❌ Missing features (bank rec, aging, POS returns)

## After Phase 4-6 (Security + Performance): 7/10
- ✅ Authentication working
- ✅ Passwords hashed
- ✅ Session management
- ✅ Reports load quickly
- ❌ Missing features (bank rec, aging, POS returns)

## After All Phases: 9.5/10
- ✅ All financial calculations correct (Decimal everywhere)
- ✅ Authentication + authorization hardened
- ✅ SQLCipher database encryption
- ✅ All reports functional (including aging, bank rec)
- ✅ POS returns integrated
- ✅ Professional packaging engine
- ✅ Configurable posting profiles
- ✅ High performance under load
- ❌ Edge case: Multi-branch reconciliation (not covered)
- ❌ Edge case: Real-time sync conflict resolution (not covered)

---

*End of IMPLEMENTATION_GUIDE.md*
