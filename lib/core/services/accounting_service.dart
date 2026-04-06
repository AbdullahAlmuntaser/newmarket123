import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:uuid/uuid.dart';
import 'audit_service.dart';
import 'package:json_annotation/json_annotation.dart';

part 'accounting_service.g.dart';

class AccountingService {
  @JsonKey(includeFromJson: false, includeToJson: false)
  final AppDatabase db;
  late final AuditService _auditService;

  AccountingService(this.db) {
    _auditService = AuditService(db);
  }

  // Standard Account Codes
  static const String codeCash = '1010';
  static const String codeBank = '1020';
  static const String codeAccountsReceivable = '1030';
  static const String codeInventory = '1040';
  static const String codeInputVAT = '1050'; // Tax on Purchases
  static const String codeFixedAssets = '1200'; 
  static const String codeAccumulatedDepreciation = '1201'; // New Contra-Asset
  static const String codeAccountsPayable = '2010';
  static const String codeOutputVAT = '2020'; // Tax on Sales
  static const String codeLoansPayable = '2500';
  static const String codeCapital = '3000';
  static const String codeRetainedEarnings = '3010';
  static const String codeSalesRevenue = '4010';
  static const String codeSalesReturns = '4020'; // New Contra-Revenue Account
  static const String codeCOGS = '5010';
  static const String codePurchaseReturns = '5011'; // New Contra-Expense Account
  static const String codeCashOverShort = '5020';
  static const String codeOperatingExpenses = '6000';
  static const String codeDepreciationExpense = '6001'; // New Expense


  Future<void> seedDefaultAccounts() async {
    final dao = db.accountingDao;

    final accounts = {
      codeCash: GLAccountsCompanion.insert(code: codeCash, name: 'الصندوق', type: 'ASSET'),
      codeBank: GLAccountsCompanion.insert(code: codeBank, name: 'البنك', type: 'ASSET'),
      codeAccountsReceivable: GLAccountsCompanion.insert(code: codeAccountsReceivable, name: 'الذمم المدينة', type: 'ASSET'),
      codeInventory: GLAccountsCompanion.insert(code: codeInventory, name: 'المخزون', type: 'ASSET'),
      codeInputVAT: GLAccountsCompanion.insert(code: codeInputVAT, name: 'ضريبة المدخلات (المشتريات)', type: 'ASSET'),
      codeFixedAssets: GLAccountsCompanion.insert(code: codeFixedAssets, name: 'الأصول الثابتة', type: 'ASSET', isHeader: const Value(true)),
      codeAccumulatedDepreciation: GLAccountsCompanion.insert(code: codeAccumulatedDepreciation, name: 'مجمع الإهلاك', type: 'ASSET'),

      codeAccountsPayable: GLAccountsCompanion.insert(code: codeAccountsPayable, name: 'الذمم الدائنة', type: 'LIABILITY'),
      codeOutputVAT: GLAccountsCompanion.insert(code: codeOutputVAT, name: 'ضريبة المخرجات (المبيعات)', type: 'LIABILITY'),
      codeLoansPayable: GLAccountsCompanion.insert(code: codeLoansPayable, name: 'القروض', type: 'LIABILITY'),
      codeCapital: GLAccountsCompanion.insert(code: codeCapital, name: 'رأس المال', type: 'EQUITY'),
      codeRetainedEarnings: GLAccountsCompanion.insert(code: codeRetainedEarnings, name: 'الأرباح المحتجزة', type: 'EQUITY'),
      codeSalesRevenue: GLAccountsCompanion.insert(code: codeSalesRevenue, name: 'إيرادات المبيعات', type: 'REVENUE'),
      codeSalesReturns: GLAccountsCompanion.insert(code: codeSalesReturns, name: 'مردودات المبيعات', type: 'REVENUE'), // Added
      codeCOGS: GLAccountsCompanion.insert(code: codeCOGS, name: 'تكلفة البضاعة المباعة', type: 'EXPENSE'),
      codePurchaseReturns: GLAccountsCompanion.insert(code: codePurchaseReturns, name: 'مردودات المشتريات', type: 'EXPENSE'), // Added
      codeCashOverShort: GLAccountsCompanion.insert(code: codeCashOverShort, name: 'العجز والزيادة في الصندوق', type: 'EXPENSE'),
      codeOperatingExpenses: GLAccountsCompanion.insert(code: codeOperatingExpenses, name: 'المصروفات التشغيلية', type: 'EXPENSE', isHeader: const Value(true)),
      codeDepreciationExpense: GLAccountsCompanion.insert(code: codeDepreciationExpense, name: 'مصروف الإهلاك', type: 'EXPENSE'),

    };

    for (var acc in accounts.values) {
      final existing = await dao.getAccountByCode(acc.code.value);
      if (existing == null) {
        await dao.createAccount(acc);
      }
    }
  }

    Future<FinancialRatiosData> getFinancialRatios() async {
    final incomeStatement = await getIncomeStatement();
    final dao = db.accountingDao;
    final asOfDate = DateTime.now();

    // 1. Gross Profit Margin
    final cogsAccount = await dao.getAccountByCode(codeCOGS);
    final cogsBalance = cogsAccount != null ? await dao.getAccountBalanceAsOfDate(cogsAccount.id, asOfDate) : 0.0;
    final grossProfit = incomeStatement.totalRevenue - cogsBalance;
    final grossProfitMargin = incomeStatement.totalRevenue > 0 ? (grossProfit / incomeStatement.totalRevenue) : 0.0;

    // 2. Net Profit Margin
    final netProfitMargin = incomeStatement.totalRevenue > 0 ? (incomeStatement.netIncome / incomeStatement.totalRevenue) : 0.0;

    // 3. Current Ratio
    final currentAssetCodes = [codeCash, codeBank, codeAccountsReceivable, codeInventory];
    final currentLiabilityCodes = [codeAccountsPayable, codeOutputVAT];
    
    double totalCurrentAssets = 0.0;
    for (var code in currentAssetCodes) {
        final account = await dao.getAccountByCode(code);
        if(account != null) totalCurrentAssets += await dao.getAccountBalanceAsOfDate(account.id, asOfDate);
    }

    double totalCurrentLiabilities = 0.0;
    for (var code in currentLiabilityCodes) {
        final account = await dao.getAccountByCode(code);
        if(account != null) totalCurrentLiabilities += await dao.getAccountBalanceAsOfDate(account.id, asOfDate);
    }

    final currentRatio = totalCurrentLiabilities > 0 ? (totalCurrentAssets / totalCurrentLiabilities) : 0.0;

    return FinancialRatiosData(
      grossProfitMargin: grossProfitMargin,
      netProfitMargin: netProfitMargin,
      currentRatio: currentRatio,
    );
  }

  Future<AccountingDashboardData> getDashboardData() async {
    final incomeStatement = await getIncomeStatement();
    final balanceSheet = await getBalanceSheet();
    final ratios = await getFinancialRatios(); // Calculate ratios

    // Top Expenses
    final topExpensesFull = List<TrialBalanceItem>.from(incomeStatement.expenses);
    topExpensesFull.sort((a, b) => b.totalDebit.compareTo(a.totalDebit));
    final top5Expenses = topExpensesFull.take(5).toList();

    // Recent Transactions
    final recentEntries = await db.accountingDao.watchRecentEntries(limit: 5).first;

    // Daily Data for last 7 days
    final now = DateTime.now();
    final last7Days = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    List<DailyValue> dailyRev = [];
    List<DailyValue> dailyExp = [];

    for (int i = 0; i < 7; i++) {
      final date = last7Days.add(Duration(days: i));
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final dayIncomeStatement = await getIncomeStatement(startDate: date, endDate: endOfDay);
      dailyRev.add(DailyValue(date, dayIncomeStatement.totalRevenue));
      dailyExp.add(DailyValue(date, dayIncomeStatement.totalExpense));
    }

    // Top Selling Products
    final topProductsFromDao = await db.salesDao.getTopSellingProducts(limit: 5);
    final topSellingProducts = topProductsFromDao.map((p) => DashboardTopProduct(p.product.name, p.totalQuantity)).toList();

    // Expiring Batches
    final expiringBatches = await db.productsDao.getExpiringBatches(daysThreshold: 30);

    return AccountingDashboardData(
      totalRevenue: incomeStatement.totalRevenue,
      totalExpenses: incomeStatement.totalExpense,
      netIncome: incomeStatement.netIncome,
      totalAssets: balanceSheet.totalAssets,
      totalLiabilities: balanceSheet.totalLiabilities,
      topExpenses: top5Expenses,
      recentTransactions: recentEntries,
      dailyRevenue: dailyRev,
      dailyExpenses: dailyExp,
      topSellingProducts: topSellingProducts,
      expiringBatchesCount: expiringBatches.length,
      ratios: ratios, // Pass ratios to the dashboard data
    );
  }

  Future<void> postSale(Sale sale, List<SaleItem> items) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    // 1. Revenue Entry
    final debitAccountCode = sale.isCredit ? codeAccountsReceivable : codeCash;
    final debitAccount = await dao.getAccountByCode(debitAccountCode);
    final revenueAccount = await dao.getAccountByCode(codeSalesRevenue);
    final taxAccount = await dao.getAccountByCode(codeOutputVAT);

    if (debitAccount == null || revenueAccount == null || taxAccount == null) {
      throw Exception('Missing one or more required GL accounts for sale.');
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Sale #${sale.id.substring(0, 8)}',
      date: Value(sale.createdAt),
      referenceType: const Value('SALE'),
      referenceId: Value(sale.id),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: debitAccount.id,
        debit: Value(sale.total),
        credit: const Value(0.0),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: revenueAccount.id,
        debit: const Value(0.0),
        credit: Value(sale.total - sale.tax),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: taxAccount.id,
        debit: const Value(0.0),
        credit: Value(sale.tax),
      ),
    ];

    await dao.createEntry(entry, lines);
    await _auditService.logCreate(
      'GLEntry',
      entryId,
      details: 'Revenue entry for Sale #${sale.id.substring(0, 8)}',
    );

    // 2. COGS Entry (applying FIFO)
    double totalCost = 0.0;
    List<Future<void>> stockUpdates = [];

    for (var item in items) {
      double remainingQuantity = item.quantity;

      // Get product batches, ordered by expiry date (FIFO for nearing expiry first, then oldest received)
      final batches = await (db.select(db.productBatches)
            ..where((b) => b.productId.equals(item.productId))
            ..orderBy([
              (b) => OrderingTerm(expression: b.expiryDate, mode: OrderingMode.asc),
              (b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.asc),
            ]))
          .get();

      for (var batch in batches) {
        if (remainingQuantity <= 0) break;

        double quantityToDeduct = 0;
        if (batch.quantity >= remainingQuantity) {
          quantityToDeduct = remainingQuantity;
          remainingQuantity = 0;
        } else {
          quantityToDeduct = batch.quantity;
          remainingQuantity -= batch.quantity;
        }

        totalCost += quantityToDeduct * batch.costPrice;

        // Update batch quantity
        stockUpdates.add(
          (db.update(db.productBatches)..where((b) => b.id.equals(batch.id)))
              .write(ProductBatchesCompanion(
            quantity: Value(batch.quantity - quantityToDeduct),
          )),
        );
      }

      if (remainingQuantity > 0) {
        // Handle case where there isn't enough stock in batches
        await _auditService.log(
          action: 'INVENTORY_DISCREPANCY',
          targetEntity: 'ProductBatches',
          entityId: item.productId,
          details:
              'Not enough stock in batches for product ${item.productId}. Remaining: $remainingQuantity',
          userId: null, 
        );
      }
    }

    // Execute all batch updates
    await Future.wait(stockUpdates);

    if (totalCost > 0) {
      final cogsEntryId = const Uuid().v4();
      final cogsAccount = await dao.getAccountByCode(codeCOGS);
      final inventoryAccount = await dao.getAccountByCode(codeInventory);

      if (cogsAccount == null || inventoryAccount == null) {
        throw Exception('Missing COGS or Inventory GL accounts.');
      }

      final cogsEntry = GLEntriesCompanion.insert(
        id: Value(cogsEntryId),
        description: 'COGS for Sale #${sale.id.substring(0, 8)}',
        date: Value(sale.createdAt),
        referenceType: const Value('COGS'),
        referenceId: Value(sale.id),
      );

      final cogsLines = [
        GLLinesCompanion.insert(
          entryId: cogsEntryId,
          accountId: cogsAccount.id,
          debit: Value(totalCost),
          credit: const Value(0.0),
        ),
        GLLinesCompanion.insert(
          entryId: cogsEntryId,
          accountId: inventoryAccount.id,
          debit: const Value(0.0),
          credit: Value(totalCost),
        ),
      ];
      await dao.createEntry(cogsEntry, cogsLines);
      await _auditService.logCreate(
        'GLEntry',
        cogsEntryId,
        details: 'COGS entry for Sale #${sale.id.substring(0, 8)}. Cost: $totalCost',
      );
    }
  }

  Future<void> postPurchase(Purchase purchase, List<PurchaseItem> items) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final inventoryAccount = await dao.getAccountByCode(codeInventory);
    final taxAccount = await dao.getAccountByCode(codeInputVAT);
    final creditAccountCode = purchase.isCredit ? codeAccountsPayable : codeCash;
    final creditAccount = await dao.getAccountByCode(creditAccountCode);

    if (inventoryAccount == null || creditAccount == null || taxAccount == null) {
      throw Exception('Missing GL accounts for purchase (Inventory, Credit, or Tax).');
    }

    final subtotal = purchase.total - purchase.tax;

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Purchase #${purchase.id.substring(0, 8)}',
      date: Value(purchase.date),
      referenceType: const Value('PURCHASE'),
      referenceId: Value(purchase.id),
    );

    final lines = [
      // Debit Inventory for the subtotal amount
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: inventoryAccount.id,
        debit: Value(subtotal),
        credit: const Value(0.0),
      ),
      // Debit Input VAT for the tax amount
      if (purchase.tax > 0) 
        GLLinesCompanion.insert(
            entryId: entryId,
            accountId: taxAccount.id,
            debit: Value(purchase.tax),
            credit: const Value(0.0)),
      // Credit Accounts Payable / Cash for the total amount
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: creditAccount.id,
        debit: const Value(0.0),
        credit: Value(purchase.total),
      ),
    ];

    await dao.createEntry(entry, lines.whereType<GLLinesCompanion>().toList());
    await _auditService.logCreate(
      'GLEntry',
      entryId,
      details: 'Purchase entry for Purchase #${purchase.id.substring(0, 8)}',
    );

    // Update supplier balance if it is a credit purchase
    if (purchase.isCredit) {
      final supplierId = purchase.supplierId;
      if (supplierId != null) {
        final supplier = await (db.select(db.suppliers)..where((tbl) => tbl.id.equals(supplierId))).getSingleOrNull();
        if (supplier != null) {
          final newBalance = supplier.balance + purchase.total;
          await (db.update(db.suppliers)..where((t) => t.id.equals(supplier.id)))
              .write(SuppliersCompanion(balance: Value(newBalance)));
        }
      }
    }
  }

  Future<void> recordCustomerPayment({
    required String customerId,
    required double amount,
    required String paymentAccountCode,
  }) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final arAccount = await dao.getAccountByCode(codeAccountsReceivable);
    final paymentAccount = await dao.getAccountByCode(paymentAccountCode);

    if (arAccount == null || paymentAccount == null) {
      throw Exception('AR or Payment account not found.');
    }

    final customer = await db.customersDao.getCustomerById(customerId);

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Payment from ${customer?.name ?? "Customer"}',
      date: Value(DateTime.now()),
      referenceType: const Value('CUSTOMER_PAYMENT'),
      referenceId: Value(customerId),
    );

    final lines = [
      // Debit Cash/Bank
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: paymentAccount.id,
        debit: Value(amount),
        credit: const Value(0.0),
      ),
      // Credit Accounts Receivable
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: arAccount.id,
        debit: const Value(0.0),
        credit: Value(amount),
      ),
    ];

    await dao.createEntry(entry, lines);
    await _auditService.logCreate(
      'GLEntry',
      entryId,
      details: 'Customer Payment: $amount for customer $customerId',
    );
  }

   Future<void> postSaleReturn(SalesReturn saleReturn, List<SalesReturnItem> items) async {
    final dao = db.accountingDao;
    final originalSale = await db.salesDao.getSaleById(saleReturn.saleId);
    if (originalSale == null) throw Exception('Original sale not found for return.');

    // 1. Reverse Revenue Entry
    final entryId = const Uuid().v4();
    final salesReturnAccount = await dao.getAccountByCode(codeSalesReturns);
    final taxAccount = await dao.getAccountByCode(codeOutputVAT);
    final arAccount = await dao.getAccountByCode(codeAccountsReceivable);
    final cashAccount = await dao.getAccountByCode(codeCash);

    if (salesReturnAccount == null || taxAccount == null || arAccount == null || cashAccount == null) {
      throw Exception('Missing accounts for sale return.');
    }

    final totalReturned = saleReturn.amountReturned;
    // Simple tax calculation for now, assuming same rate as original sale
    final taxPortion = originalSale.tax > 0 ? (totalReturned / originalSale.total) * originalSale.tax : 0.0;
    final revenuePortion = totalReturned - taxPortion;
    
    // Determine which account to credit (Cash or A/R)
    final creditAccount = originalSale.isCredit ? arAccount : cashAccount;

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Sale Return for Sale #${originalSale.id.substring(0,8)}',
      date: Value(saleReturn.createdAt),
      referenceType: const Value('SALE_RETURN'),
      referenceId: Value(saleReturn.id),
    );

    final lines = [
      // Debit Sales Returns (Contra-Revenue)
      GLLinesCompanion.insert( entryId: entryId, accountId: salesReturnAccount.id, debit: Value(revenuePortion), credit: const Value(0.0)),
      // Debit Output VAT (to reverse the tax liability)
      GLLinesCompanion.insert( entryId: entryId, accountId: taxAccount.id, debit: Value(taxPortion), credit: const Value(0.0)),
      // Credit A/R or Cash
      GLLinesCompanion.insert( entryId: entryId, accountId: creditAccount.id, debit: const Value(0.0), credit: Value(totalReturned)),
    ];

    await dao.createEntry(entry, lines);

    // 2. Reverse COGS Entry (Return items to inventory)
    double totalCostReversed = 0;
    for (var item in items) {
      // For simplicity, we'll use the product's current buy price. 
      // A more complex system might store the cost at time of sale.
      final product = await db.productsDao.getProductById(item.productId);
      if (product != null) {
        totalCostReversed += item.quantity * product.buyPrice; 
        // Here you would also update inventory stock, potentially in a specific batch
      }
    }

    if (totalCostReversed > 0) {
      final cogsEntryId = const Uuid().v4();
      final cogsAccount = await dao.getAccountByCode(codeCOGS);
      final inventoryAccount = await dao.getAccountByCode(codeInventory);
      
      if(cogsAccount == null || inventoryAccount == null) return;

      final cogsEntry = GLEntriesCompanion.insert(
        id: Value(cogsEntryId),
        description: 'COGS Reversal for Sale Return #${saleReturn.id.substring(0,8)}',
        date: Value(saleReturn.createdAt),
        referenceType: const Value('COGS_REVERSAL'),
        referenceId: Value(saleReturn.id),
      );
      final cogsLines = [
        // Debit Inventory
        GLLinesCompanion.insert(entryId: cogsEntryId, accountId: inventoryAccount.id, debit: Value(totalCostReversed), credit: const Value(0.0)),
        // Credit COGS
        GLLinesCompanion.insert(entryId: cogsEntryId, accountId: cogsAccount.id, debit: const Value(0.0), credit: Value(totalCostReversed)),
      ];
      await dao.createEntry(cogsEntry, cogsLines);
    }
  }

  Future<void> postPurchaseReturn(PurchaseReturn purchaseReturn, List<PurchaseReturnItem> items) async {
    final dao = db.accountingDao;
    final originalPurchase = await db.purchasesDao.getPurchaseById(purchaseReturn.purchaseId);
    if (originalPurchase == null) throw Exception('Original purchase not found for return.');

    // 1. Reverse Purchase Entry
    final entryId = const Uuid().v4();
    final purchaseReturnAccount = await dao.getAccountByCode(codePurchaseReturns);
    final taxAccount = await dao.getAccountByCode(codeInputVAT);
    final apAccount = await dao.getAccountByCode(codeAccountsPayable);
    final cashAccount = await dao.getAccountByCode(codeCash);

    if (purchaseReturnAccount == null || taxAccount == null || apAccount == null || cashAccount == null) {
      throw Exception('Missing accounts for purchase return.');
    }

    final totalReturned = purchaseReturn.amountReturned;
    // Simple tax calculation for now, assuming same rate as original purchase
    final taxPortion = originalPurchase.tax > 0 ? (totalReturned / originalPurchase.total) * originalPurchase.tax : 0.0;
    final purchasePortion = totalReturned - taxPortion;
    
    // Determine which account to debit (Cash or A/P)
    final debitAccount = originalPurchase.isCredit ? apAccount : cashAccount;

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Purchase Return for Purchase #${originalPurchase.id.substring(0,8)}',
      date: Value(purchaseReturn.createdAt),
      referenceType: const Value('PURCHASE_RETURN'),
      referenceId: Value(purchaseReturn.id),
    );

    final lines = [
      // Debit A/P or Cash
      GLLinesCompanion.insert( entryId: entryId, accountId: debitAccount.id, debit: Value(totalReturned), credit: const Value(0.0)),
      // Credit Purchase Returns (Contra-Expense)
      GLLinesCompanion.insert( entryId: entryId, accountId: purchaseReturnAccount.id, debit: const Value(0.0), credit: Value(purchasePortion)),
      // Credit Input VAT (to reverse the tax asset)
      GLLinesCompanion.insert( entryId: entryId, accountId: taxAccount.id, debit: const Value(0.0), credit: Value(taxPortion)),
    ];

    await dao.createEntry(entry, lines);

    // 2. Update Inventory (Decrease stock)
    for (var _ in items) {
      // Here you would decrease inventory stock.
      // This might involve finding the specific batch and reducing its quantity.
    }
  }


  Future<VatReportData> getVatReport({DateTime? startDate, DateTime? endDate}) async {
    final dao = db.accountingDao;
    final reportStartDate = startDate ?? DateTime(2000);
    final reportEndDate = endDate ?? DateTime.now();

    final outputVatAccount = await dao.getAccountByCode(codeOutputVAT);
    final inputVatAccount = await dao.getAccountByCode(codeInputVAT);

    if (outputVatAccount == null || inputVatAccount == null) {
      throw Exception('Output VAT or Input VAT accounts not found.');
    }

    final outputVatLines = await (db.select(db.gLLines).join([
          innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
        ])
        ..where(
          db.gLLines.accountId.equals(outputVatAccount.id) &
          db.gLEntries.date.isBetweenValues(reportStartDate, reportEndDate),
        ))
        .get();

    double totalOutputVat = 0.0;
    for (final line in outputVatLines) {
      totalOutputVat += (line.read(db.gLLines.credit) ?? 0) - (line.read(db.gLLines.debit) ?? 0);
    }

    final inputVatLines = await (db.select(db.gLLines).join([
          innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
        ])
        ..where(
          db.gLLines.accountId.equals(inputVatAccount.id) &
          db.gLEntries.date.isBetweenValues(reportStartDate, reportEndDate),
        ))
        .get();

    double totalInputVat = 0.0;
    for (final line in inputVatLines) {
      totalInputVat += (line.read(db.gLLines.debit) ?? 0) - (line.read(db.gLLines.credit) ?? 0);
    }

    final netVatPayable = totalOutputVat - totalInputVat;

    return VatReportData(
      totalOutputVat: totalOutputVat,
      totalInputVat: totalInputVat,
      netVatPayable: netVatPayable,
      startDate: reportStartDate,
      endDate: reportEndDate,
    );
  }

  Future<void> closeFinancialYear(DateTime endDate) async {
    final incomeStatement = await getIncomeStatement(endDate: endDate);
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();
    final retainedEarningsAcc = await dao.getAccountByCode(codeRetainedEarnings);

    if (retainedEarningsAcc == null) return;

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'إغلاق السنة المالية حتى ${endDate.toIso8601String().split('T')[0]}',
      date: Value(endDate),
      referenceType: const Value('YEAR_END'),
    );

    List<GLLinesCompanion> lines = [];

    for (var rev in incomeStatement.revenues) {
      double balance = rev.totalCredit - rev.totalDebit;
      if (balance != 0) {
        lines.add(GLLinesCompanion.insert(
          entryId: entryId,
          accountId: rev.account.id,
          debit: Value(balance),
          credit: const Value(0.0),
          memo: const Value('Year End Closing'),
        ));
      }
    }

    for (var exp in incomeStatement.expenses) {
      double balance = exp.totalDebit - exp.totalCredit;
      if (balance != 0) {
        lines.add(GLLinesCompanion.insert(
          entryId: entryId,
          accountId: exp.account.id,
          debit: const Value(0.0),
          credit: Value(balance),
          memo: const Value('Year End Closing'),
        ));
      }
    }

    if (incomeStatement.netIncome != 0) {
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: retainedEarningsAcc.id,
        debit: Value(incomeStatement.netIncome < 0 ? incomeStatement.netIncome.abs() : 0.0),
        credit: Value(incomeStatement.netIncome > 0 ? incomeStatement.netIncome : 0.0),
        memo: const Value('Net Income Transfer'),
      ));
    }

    if (lines.isNotEmpty) {
      await dao.createEntry(entry, lines);
      await _auditService.log(
        action: 'CLOSE_YEAR',
        targetEntity: 'FinancialYear',
        entityId: endDate.toIso8601String(),
        details: 'Financial year closed up to ${endDate.toIso8601String()}',
      );
    }
  }

  Future<IncomeStatementData> getIncomeStatement({DateTime? startDate, DateTime? endDate}) async {
    final dao = db.accountingDao;
    final allAccounts = await dao.getAllAccounts();
    final revenueAccounts = allAccounts.where((acc) => acc.type == 'REVENUE');
    final expenseAccounts = allAccounts.where((acc) => acc.type == 'EXPENSE');

    final List<TrialBalanceItem> revenues = [];
    for (var account in revenueAccounts) {
      final balance = await dao.getAccountBalanceAsOfDate(account.id, endDate ?? DateTime.now());
      revenues.add(TrialBalanceItem(account, 0.0, balance));
    }

    final List<TrialBalanceItem> expenses = [];
    for (var account in expenseAccounts) {
      final balance = await dao.getAccountBalanceAsOfDate(account.id, endDate ?? DateTime.now());
      expenses.add(TrialBalanceItem(account, balance, 0.0));
    }

    double totalRevenue = revenues.fold(0, (sum, item) => sum + item.totalCredit);
    double totalExpense = expenses.fold(0, (sum, item) => sum + item.totalDebit);

    return IncomeStatementData(
      revenues: revenues,
      expenses: expenses,
      totalRevenue: totalRevenue,
      totalExpense: totalExpense,
      netIncome: totalRevenue - totalExpense,
      startDate: startDate,
      endDate: endDate ?? DateTime.now(),
    );
  }

  Future<BalanceSheetData> getBalanceSheet({DateTime? date}) async {
    final dao = db.accountingDao;
    final asOfDate = date ?? DateTime.now();

    final allAccounts = await dao.getAllAccounts();

    final List<BalanceSheetItem> assets = [];
    final assetAccounts = allAccounts.where((acc) => acc.type == 'ASSET');
    for (var account in assetAccounts) {
      if (!account.isHeader) {
        final balance = await dao.getAccountBalanceAsOfDate(account.id, asOfDate);
        assets.add(BalanceSheetItem(account, balance));
      }
    }

    final List<BalanceSheetItem> liabilities = [];
    final liabilityAccounts = allAccounts.where((acc) => acc.type == 'LIABILITY');
    for (var account in liabilityAccounts) {
      if (!account.isHeader) {
        final balance = await dao.getAccountBalanceAsOfDate(account.id, asOfDate);
        liabilities.add(BalanceSheetItem(account, balance));
      }
    }

    final List<BalanceSheetItem> equity = [];
    final equityAccounts = allAccounts.where((acc) => acc.type == 'EQUITY');
    for (var account in equityAccounts) {
      if (!account.isHeader) {
        final balance = await dao.getAccountBalanceAsOfDate(account.id, asOfDate);
        equity.add(BalanceSheetItem(account, balance));
      }
    }

    double totalAssets = assets.fold(0, (sum, item) => sum + item.balance);
    double totalLiabilities = liabilities.fold(0, (sum, item) => sum + item.balance);
    double totalEquity = equity.fold(0, (sum, item) => sum + item.balance);

    final incomeStatement = await getIncomeStatement(endDate: asOfDate);
    totalEquity += incomeStatement.netIncome;

    return BalanceSheetData(
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      totalEquity: totalEquity,
      netIncome: incomeStatement.netIncome,
      date: asOfDate,
    );
  }

  Future<void> recordExpense({required String description, required double amount, required DateTime date, required String expenseAccountId, required String paymentAccountId}) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: description,
      date: Value(date),
      referenceType: const Value('EXPENSE'),
    );

    final lines = [
      GLLinesCompanion.insert(entryId: entryId, accountId: expenseAccountId, debit: Value(amount), credit: const Value(0.0)),
      GLLinesCompanion.insert(entryId: entryId, accountId: paymentAccountId, debit: const Value(0.0), credit: Value(amount)),
    ];

    await dao.createEntry(entry, lines);
    await _auditService.logCreate('Expense', entryId, details: 'Expense: $description, Amount: $amount');
  }

  Future<CashFlowData> getCashFlowStatement({DateTime? startDate, DateTime? endDate}) async {
    final dao = db.accountingDao;
    final reportStartDate = startDate ?? DateTime(2000);
    final reportEndDate = endDate ?? DateTime.now();

    final glLinesWithAccounts = await dao.getGLLinesWithEntriesInDateRange(reportStartDate, reportEndDate);

    double operatingActivities = 0.0;
    double investingActivities = 0.0;
    double financingActivities = 0.0;

    final cashAccounts = await dao.getAccountsByType('ASSET');
    final cashAccountIds = cashAccounts.where((acc) => acc.code == codeCash || acc.code == codeBank).map((acc) => acc.id).toSet();

    double beginningCashBalance = 0.0;
    if (reportStartDate != DateTime(2000)) {
      for (var cashAccountId in cashAccountIds) {
        beginningCashBalance += await dao.getAccountBalanceAsOfDate(cashAccountId, reportStartDate.subtract(const Duration(milliseconds: 1)));
      }
    }

    final entriesMap = <String, List<GLLineWithAccount>>{};
    for (var lineWithAcc in glLinesWithAccounts) {
      entriesMap.update(lineWithAcc.line.entryId, (list) => list..add(lineWithAcc), ifAbsent: () => [lineWithAcc]);
    }

    for (var entryId in entriesMap.keys) {
      final lines = entriesMap[entryId]!;

      double cashMovement = 0.0;
      bool involvesCash = false;

      for (var line in lines) {
        if (cashAccountIds.contains(line.account.id)) {
          cashMovement += (line.line.debit - line.line.credit);
          involvesCash = true;
        }
      }

      if (!involvesCash || cashMovement == 0.0) continue;

      bool categorized = false;
      for (var line in lines) {
        if (!cashAccountIds.contains(line.account.id)) {
          final accountType = line.account.type;
          final accountCode = line.account.code;

          if (accountType == 'REVENUE' || accountType == 'EXPENSE' || accountCode == codeAccountsReceivable || accountCode == codeAccountsPayable || accountCode == codeInputVAT || accountCode == codeOutputVAT) {
            operatingActivities += cashMovement;
            categorized = true;
            break;
          } else if (accountCode == codeFixedAssets) {
            investingActivities += cashMovement;
            categorized = true;
            break;
          } else if (accountCode == codeLoansPayable || accountCode == codeCapital) {
            financingActivities += cashMovement;
            categorized = true;
            break;
          }
        }
      }
      if (!categorized) {
        operatingActivities += cashMovement;
      }
    }

    final netCashFlow = operatingActivities + investingActivities + financingActivities;
    final endingCashBalance = beginningCashBalance + netCashFlow;

    return CashFlowData(
      operatingActivities: operatingActivities,
      investingActivities: investingActivities,
      financingActivities: financingActivities,
      netCashFlow: netCashFlow,
      beginningCashBalance: beginningCashBalance,
      endingCashBalance: endingCashBalance,
      startDate: reportStartDate,
      endDate: reportEndDate,
    );
  }
}


@JsonSerializable()
class VatReportData {
  final double totalOutputVat;
  final double totalInputVat;
  final double netVatPayable;
  final DateTime startDate;
  final DateTime endDate;

  VatReportData({
    required this.totalOutputVat,
    required this.totalInputVat,
    required this.netVatPayable,
    required this.startDate,
    required this.endDate,
  });

  factory VatReportData.fromJson(Map<String, dynamic> json) => _$VatReportDataFromJson(json);
  Map<String, dynamic> toJson() => _$VatReportDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class IncomeStatementData {
  final List<TrialBalanceItem> revenues;
  final List<TrialBalanceItem> expenses;
  final double totalRevenue;
  final double totalExpense;
  final double netIncome;
  final DateTime? startDate;
  final DateTime endDate;

  IncomeStatementData({
    required this.revenues,
    required this.expenses,
    required this.totalRevenue,
    required this.totalExpense,
    required this.netIncome,
    this.startDate,
    required this.endDate,
  });

  factory IncomeStatementData.fromJson(Map<String, dynamic> json) => _$IncomeStatementDataFromJson(json);
  Map<String, dynamic> toJson() => _$IncomeStatementDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class BalanceSheetData {
  final List<BalanceSheetItem> assets;
  final List<BalanceSheetItem> liabilities;
  final List<BalanceSheetItem> equity;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final double netIncome;
  final DateTime date;

  BalanceSheetData({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.netIncome,
    required this.date,
  });

  factory BalanceSheetData.fromJson(Map<String, dynamic> json) => _$BalanceSheetDataFromJson(json);
  Map<String, dynamic> toJson() => _$BalanceSheetDataToJson(this);
}

class GLAccountConverter implements JsonConverter<GLAccount, Map<String, dynamic>> {
  const GLAccountConverter();

  @override
  GLAccount fromJson(Map<String, dynamic> json) => GLAccount.fromJson(json);

  @override
  Map<String, dynamic> toJson(GLAccount object) => object.toJson();
}

class GLEntryConverter implements JsonConverter<GLEntry, Map<String, dynamic>> {
  const GLEntryConverter();

  @override
  GLEntry fromJson(Map<String, dynamic> json) => GLEntry.fromJson(json);

  @override
  Map<String, dynamic> toJson(GLEntry object) => object.toJson();
}

@JsonSerializable(explicitToJson: true)
class BalanceSheetItem {
  @GLAccountConverter()
  final GLAccount account;
  final double balance;

  BalanceSheetItem(this.account, this.balance);

  factory BalanceSheetItem.fromJson(Map<String, dynamic> json) => _$BalanceSheetItemFromJson(json);
  Map<String, dynamic> toJson() => _$BalanceSheetItemToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AccountingDashboardData {
  final double totalRevenue;
  final double totalExpenses;
  final double netIncome;
  final double totalAssets;
  final double totalLiabilities;
  final List<TrialBalanceItem> topExpenses;
  @GLEntryConverter()
  final List<GLEntry> recentTransactions;
  final List<DailyValue> dailyRevenue;
  final List<DailyValue> dailyExpenses;
  final List<DashboardTopProduct> topSellingProducts;
  final int expiringBatchesCount;
  final FinancialRatiosData ratios; // Added ratios

  AccountingDashboardData({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netIncome,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.topExpenses,
    required this.recentTransactions,
    required this.dailyRevenue,
    required this.dailyExpenses,
    required this.topSellingProducts,
    this.expiringBatchesCount = 0,
    required this.ratios, // Make it required
  });

  factory AccountingDashboardData.fromJson(Map<String, dynamic> json) => _$AccountingDashboardDataFromJson(json);
  Map<String, dynamic> toJson() => _$AccountingDashboardDataToJson(this);
}

@JsonSerializable()
class DashboardTopProduct {
  final String productName;
  final double quantity;
  DashboardTopProduct(this.productName, this.quantity);

  factory DashboardTopProduct.fromJson(Map<String, dynamic> json) => _$DashboardTopProductFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardTopProductToJson(this);
}

@JsonSerializable()
class DailyValue {
  final DateTime date;
  final double value;
  DailyValue(this.date, this.value);

  factory DailyValue.fromJson(Map<String, dynamic> json) => _$DailyValueFromJson(json);
  Map<String, dynamic> toJson() => _$DailyValueToJson(this);
}

@JsonSerializable()
class CashFlowData {
  final double operatingActivities;
  final double investingActivities;
  final double financingActivities;
  final double netCashFlow;
  final double beginningCashBalance;
  final double endingCashBalance;
  final DateTime? startDate;
  final DateTime endDate;

  CashFlowData({
    required this.operatingActivities,
    required this.investingActivities,
    required this.financingActivities,
    required this.netCashFlow,
    required this.beginningCashBalance,
    required this.endingCashBalance,
    this.startDate,
    required this.endDate,
  });

  factory CashFlowData.fromJson(Map<String, dynamic> json) => _$CashFlowDataFromJson(json);
  Map<String, dynamic> toJson() => _$CashFlowDataToJson(this);
}

@JsonSerializable()
class FinancialRatiosData {
  final double grossProfitMargin;
  final double netProfitMargin;
  final double currentRatio;

  FinancialRatiosData({
    required this.grossProfitMargin,
    required this.netProfitMargin,
    required this.currentRatio,
  });

  factory FinancialRatiosData.fromJson(Map<String, dynamic> json) => _$FinancialRatiosDataFromJson(json);
  Map<String, dynamic> toJson() => _$FinancialRatiosDataToJson(this);
}
