import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

/// Comprehensive Purchase Service for ERP
/// Handles all purchase invoice operations including:
/// - Invoice creation with items
/// - Calculations (unit conversion, subtotals, taxes, discounts)
/// - Additional costs distribution
/// - Posting (inventory, batch creation, journal entries)
/// - Supplier balance management

class PurchaseService {
  final AppDatabase db;
  final _uuid = const Uuid();

  PurchaseService(this.db);

  // ==================== CALCULATIONS ====================

  /// Calculate quantity in base unit based on unit factor
  static double calculateBaseQuantity({
    required double quantity,
    required double unitFactor,
  }) {
    return quantity * unitFactor;
  }

  /// Calculate subtotal for an item (quantity * unitPrice)
  static double calculateSubtotal({
    required double quantity,
    required double unitPrice,
  }) {
    return quantity * unitPrice;
  }

  /// Calculate discount amount
  static double calculateDiscount({
    required double subtotal,
    double discountPercent = 0,
    double discountAmount = 0,
  }) {
    if (discountPercent > 0) {
      return subtotal * (discountPercent / 100);
    }
    return discountAmount;
  }

  /// Calculate tax amount
  static double calculateTax({
    required double amountAfterDiscount,
    double taxPercent = 0,
  }) {
    return amountAfterDiscount * (taxPercent / 100);
  }

  /// Calculate item total with discount and tax
  static double calculateItemTotal({
    required double quantity,
    required double unitPrice,
    double discountPercent = 0,
    double discountAmount = 0,
    double taxPercent = 0,
  }) {
    final subtotal = calculateSubtotal(
      quantity: quantity,
      unitPrice: unitPrice,
    );
    final discount = calculateDiscount(
      subtotal: subtotal,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
    );
    final afterDiscount = subtotal - discount;
    final tax = calculateTax(
      amountAfterDiscount: afterDiscount,
      taxPercent: taxPercent,
    );
    return afterDiscount + tax;
  }

  /// Calculate purchase header totals
  static PurchaseTotals calculateHeaderTotals({
    required List<PurchaseItemCalculated> items,
    double shippingCost = 0,
    double otherExpenses = 0,
    double landedCosts = 0,
    double headerDiscount = 0,
  }) {
    double subtotal = 0;
    double totalDiscount = 0;
    double totalTax = 0;

    for (var item in items) {
      subtotal += item.subtotal;
      totalDiscount += item.discount;
      totalTax += item.tax;
    }

    final goodsAmount = subtotal - totalDiscount;
    final additionalCosts =
        shippingCost + otherExpenses + landedCosts - headerDiscount;
    final grandTotal = goodsAmount + totalTax + additionalCosts;

    return PurchaseTotals(
      subtotal: subtotal,
      discount: totalDiscount + headerDiscount,
      tax: totalTax,
      shippingCost: shippingCost,
      otherExpenses: otherExpenses,
      landedCosts: landedCosts,
      grandTotal: grandTotal,
    );
  }

  // ==================== COST DISTRIBUTION ====================

  /// Distribute additional costs based on quantity
  static List<CostDistribution> distributeByQuantity({
    required List<CostDistributionItem> items,
    required double totalCost,
  }) {
    if (items.isEmpty) return [];

    final totalQuantity = items.fold<double>(
      0,
      (sum, item) => sum + item.baseQuantity,
    );
    if (totalQuantity == 0) {
      // Equal distribution if no quantity
      final perItem = totalCost / items.length;
      return items
          .map(
            (item) =>
                CostDistribution(productId: item.productId, costShare: perItem),
          )
          .toList();
    }

    return items.map((item) {
      final share = (item.baseQuantity / totalQuantity) * totalCost;
      return CostDistribution(productId: item.productId, costShare: share);
    }).toList();
  }

  /// Distribute additional costs based on value (subtotal)
  static List<CostDistribution> distributeByValue({
    required List<CostDistributionItem> items,
    required double totalCost,
  }) {
    if (items.isEmpty) return [];

    final totalValue = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    if (totalValue == 0) {
      final perItem = totalCost / items.length;
      return items
          .map(
            (item) =>
                CostDistribution(productId: item.productId, costShare: perItem),
          )
          .toList();
    }

    return items.map((item) {
      final share = (item.subtotal / totalValue) * totalCost;
      return CostDistribution(productId: item.productId, costShare: share);
    }).toList();
  }

  // ==================== CREATE PURCHASE ====================

  /// Create a new purchase invoice (draft)
  Future<String> createPurchase({
    required PurchasesCompanion purchaseCompanion,
    required List<PurchaseItemsCompanion> itemsCompanions,
    required String? userId,
  }) async {
    if (itemsCompanions.isEmpty) {
      throw Exception('لا يمكن إنشاء فاتورة مشتريات بدون أصناف.');
    }

    final purchaseId = purchaseCompanion.id.value;

    // Calculate totals
    double totalSubtotal = 0;
    double totalTax = 0;

    for (var item in itemsCompanions) {
      final qty = item.quantity.value;
      final price = item.price.value;
      totalSubtotal += qty * price;
      // Calculate tax if taxRate is provided (stored in product)
      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(item.productId.value))).getSingleOrNull();
      if (product != null && product.taxRate > 0) {
        totalTax += (qty * price) * (product.taxRate / 100);
      }
    }

    return await db.transaction(() async {
      // 1. Insert Purchase
      final total =
          totalSubtotal + totalTax + purchaseCompanion.landedCosts.value;

      await db
          .into(db.purchases)
          .insert(
            purchaseCompanion.copyWith(
              total: Value(total),
              tax: Value(totalTax),
            ),
          );

      // 2. Insert Items
      for (var item in itemsCompanions) {
        await db.into(db.purchaseItems).insert(item);
      }

      // 3. Audit Log
      await db
          .into(db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              action: 'CREATE',
              targetEntity: 'PURCHASES',
              entityId: purchaseId,
              details: Value('Created purchase invoice: $purchaseId'),
            ),
          );

      return purchaseId;
    });
  }

  // ==================== POST PURCHASE ====================

  /// Post a purchase invoice (create inventory, batches, journal entries)
  Future<void> postPurchase({
    required String purchaseId,
    required String? userId,
    String costDistributionMethod = 'quantity',
  }) async {
    // Get purchase header
    final purchase = await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingle();

    if (purchase.status == 'POSTED' || purchase.status == 'RECEIVED') {
      throw Exception('الفاتورة مرحلت already');
    }

    if (purchase.status == 'CANCELLED') {
      throw Exception('Cannot post cancelled invoice');
    }

    // Get purchase items
    final items = await (db.select(
      db.purchaseItems,
    )..where((pi) => pi.purchaseId.equals(purchaseId))).get();

    if (items.isEmpty) {
      throw Exception('لا توجد أصناف في الفاتورة');
    }

    // Get supplier if exists
    Supplier? supplier;
    if (purchase.supplierId != null) {
      final supplierList = await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(purchase.supplierId!))).get();
      if (supplierList.isNotEmpty) {
        supplier = supplierList.first;
      }
    }

    // Get warehouse
    String warehouseId = purchase.warehouseId ?? '';
    if (warehouseId.isEmpty) {
      final warehouse = await (db.select(
        db.warehouses,
      )..where((w) => w.isDefault.equals(true))).getSingleOrNull();
      warehouseId = warehouse?.id ?? '';
    }

    // Calculate additional costs
    final additionalCosts = purchase.landedCosts;

    // Prepare cost distribution (simple by value)
    final itemData = items.map((item) {
      return CostDistributionItem(
        productId: item.productId,
        baseQuantity: item.quantity, // Use quantity as base
        subtotal: item.quantity * item.price,
      );
    }).toList();

    // Distribute costs
    List<CostDistribution> costDistribution = [];
    if (additionalCosts > 0) {
      if (costDistributionMethod == 'quantity') {
        costDistribution = distributeByQuantity(
          items: itemData,
          totalCost: additionalCosts,
        );
      } else {
        costDistribution = distributeByValue(
          items: itemData,
          totalCost: additionalCosts,
        );
      }
    }

    final costMap = <String, double>{};
    for (var item in costDistribution) {
      costMap[item.productId] = item.costShare;
    }

    // Process each item
    for (var item in items) {
      await _processPurchaseItem(
        item: item,
        warehouseId: warehouseId,
        costShare: costMap[item.productId] ?? 0,
        referenceId: purchaseId,
      );
    }

    // Update supplier balance if credit purchase
    if (purchase.isCredit && supplier != null) {
      await _updateSupplierBalance(
        supplierId: supplier.id,
        amount: purchase.total,
        isIncrease: true,
      );
      // Create journal entry for credit purchase
      await _createJournalEntry(
        purchase: purchase,
        supplier: supplier,
        isCredit: true,
      );
    } else {
      // Create journal entry for cash purchase
      await _createJournalEntry(
        purchase: purchase,
        supplier: supplier,
        isCredit: false,
      );
    }

    // Update purchase status
    await (db.update(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).write(
      PurchasesCompanion(
        status: const Value('POSTED'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Audit log
    await db
        .into(db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            userId: Value(userId),
            action: 'POST',
            targetEntity: 'PURCHASES',
            entityId: purchaseId,
            details: Value('Posted purchase invoice: $purchaseId'),
          ),
        );
  }

  Future<void> _processPurchaseItem({
    required PurchaseItem item,
    required String warehouseId,
    required double costShare,
    required String referenceId,
  }) async {
    if (warehouseId.isEmpty) return;
    // Create inventory transaction
    await db
        .into(db.inventoryTransactions)
        .insert(
          InventoryTransactionsCompanion(
            productId: Value(item.productId),
            warehouseId: Value(warehouseId.isEmpty ? '' : warehouseId),
            quantity: Value(item.quantity),
            type: const Value('PURCHASE'),
            referenceId: Value(referenceId),
          ),
        );
  }

  Future<void> _updateSupplierBalance({
    required String supplierId,
    required double amount,
    required bool isIncrease,
  }) async {
    final supplier = await (db.select(
      db.suppliers,
    )..where((s) => s.id.equals(supplierId))).getSingle();

    final newBalance = isIncrease
        ? supplier.balance + amount
        : supplier.balance - amount;

    await (db.update(db.suppliers)..where((s) => s.id.equals(supplierId)))
        .write(SuppliersCompanion(balance: Value(newBalance)));
  }

  /// Create journal entry for purchase
  Future<void> _createJournalEntry({
    required Purchase purchase,
    required Supplier? supplier,
    required bool isCredit,
  }) async {
    final entryId = _uuid.v4();
    final totalAmount = purchase.total;
    final goodsAmount = totalAmount - purchase.tax;
    final taxAmount = purchase.tax;
    final description =
        'مشتريات - ${supplier?.name ?? "غير محدد"} - ${purchase.invoiceNumber ?? purchase.id}';

    // Create GL Entry header
    await db
        .into(db.gLEntries)
        .insert(
          GLEntriesCompanion(
            description: Value(description),
            date: Value(purchase.date),
            referenceType: const Value('PURCHASE'),
            referenceId: Value(purchase.id),
            status: const Value('POSTED'),
          ),
        );

    // Find inventory account (code 1501 - Inventory)
    final inventoryAccounts = await (db.select(
      db.gLAccounts,
    )..where((a) => a.code.equals('1501'))).get();
    final inventoryAccount = inventoryAccounts.isNotEmpty
        ? inventoryAccounts.first
        : null;

    // Find VAT account (code 2101 - VAT Payable)
    final vatAccounts = await (db.select(
      db.gLAccounts,
    )..where((a) => a.code.equals('2101'))).get();
    final vatAccount = vatAccounts.isNotEmpty ? vatAccounts.first : null;

    // Find Cash account (code 1001 - Cash)
    final cashAccounts = await (db.select(
      db.gLAccounts,
    )..where((a) => a.code.equals('1001'))).get();
    final cashAccount = cashAccounts.isNotEmpty ? cashAccounts.first : null;

    // Find Accounts Payable (code 2102)
    final payableAccounts = await (db.select(
      db.gLAccounts,
    )..where((a) => a.code.equals('2102'))).get();
    final payableAccount = payableAccounts.isNotEmpty
        ? payableAccounts.first
        : null;

    if (goodsAmount > 0 && inventoryAccount != null) {
      // Debit Inventory
      await db
          .into(db.gLLines)
          .insert(
            GLLinesCompanion(
              entryId: Value(entryId),
              accountId: Value(inventoryAccount.id),
              debit: Value(goodsAmount),
            ),
          );
    }

    if (taxAmount > 0 && vatAccount != null) {
      // Debit VAT
      await db
          .into(db.gLLines)
          .insert(
            GLLinesCompanion(
              entryId: Value(entryId),
              accountId: Value(vatAccount.id),
              debit: Value(taxAmount),
            ),
          );
    }

    if (isCredit && payableAccount != null) {
      // Credit Accounts Payable
      await db
          .into(db.gLLines)
          .insert(
            GLLinesCompanion(
              entryId: Value(entryId),
              accountId: Value(payableAccount.id),
              credit: Value(totalAmount),
            ),
          );
    } else if (cashAccount != null) {
      // Credit Cash
      await db
          .into(db.gLLines)
          .insert(
            GLLinesCompanion(
              entryId: Value(entryId),
              accountId: Value(cashAccount.id),
              credit: Value(totalAmount),
            ),
          );
    }
  }

  // ==================== CANCEL PURCHASE ====================

  /// Cancel a posted purchase
  Future<void> cancelPurchase({
    required String purchaseId,
    required String? userId,
  }) async {
    final purchase = await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingle();

    if (purchase.status != 'POSTED') {
      throw Exception('Only posted purchases can be cancelled');
    }

    final items = await (db.select(
      db.purchaseItems,
    )..where((pi) => pi.purchaseId.equals(purchaseId))).get();

    // Get warehouse
    String warehouseId = purchase.warehouseId ?? '';
    if (warehouseId.isEmpty) {
      final warehouse = await (db.select(
        db.warehouses,
      )..where((w) => w.isDefault.equals(true))).getSingleOrNull();
      warehouseId = warehouse?.id ?? '';
    }

    // Process inventory transactions (negative)
    for (var item in items) {
      await db
          .into(db.inventoryTransactions)
          .insert(
            InventoryTransactionsCompanion(
              productId: Value(item.productId),
              warehouseId: Value(warehouseId.isEmpty ? '' : warehouseId),
              quantity: Value(-item.quantity), // Negative for cancellation
              type: const Value('PURCHASE_CANCEL'),
              referenceId: Value(purchaseId),
            ),
          );
    }

    // Revert supplier balance
    if (purchase.isCredit && purchase.supplierId != null) {
      await _updateSupplierBalance(
        supplierId: purchase.supplierId!,
        amount: purchase.total,
        isIncrease: false,
      );
    }

    // Update status
    await (db.update(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).write(
      PurchasesCompanion(
        status: const Value('CANCELLED'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Audit log
    await db
        .into(db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            userId: Value(userId),
            action: 'CANCEL',
            targetEntity: 'PURCHASES',
            entityId: purchaseId,
            details: Value('Cancelled purchase invoice: $purchaseId'),
          ),
        );
  }

  // ==================== SUPPLIER PAYMENTS ====================

  /// Pay supplier (full or partial)
  Future<void> paySupplier({
    required String supplierId,
    required double amount,
    required List<SupplierPaymentLink> payments,
    String? note,
    String? userId,
  }) async {
    if (payments.isEmpty) {
      throw Exception('لا توجد فواتير للدفع');
    }

    final totalPayment = payments.fold<double>(0, (sum, p) => sum + p.amount);
    if (totalPayment > amount) {
      throw Exception('المبلغ المدفوع أقل من المطلوب');
    }

    final paymentId = _uuid.v4();

    await db.transaction(() async {
      // Create payment
      await db
          .into(db.supplierPayments)
          .insert(
            SupplierPaymentsCompanion(
              supplierId: Value(supplierId),
              amount: Value(amount),
              note: Value(note),
            ),
          );

      // Link payments to purchases and update balances
      for (var payment in payments) {
        // Get purchase and update supplier balance directly (without link table)
        final purchase = await (db.select(
          db.purchases,
        )..where((p) => p.id.equals(payment.purchaseId))).getSingleOrNull();

        if (purchase != null &&
            purchase.isCredit &&
            purchase.supplierId != null) {
          await _updateSupplierBalance(
            supplierId: purchase.supplierId!,
            amount: payment.amount,
            isIncrease: false,
          );
        }
      }

      // Audit log
      await db
          .into(db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              action: 'PAYMENT',
              targetEntity: 'SUPPLIER_PAYMENTS',
              entityId: paymentId,
              details: Value('Payment to supplier: $paymentId'),
            ),
          );
    });
  }

  // ==================== GENERATE INVOICE NUMBER ====================

  /// Generate next invoice number
  Future<String> generateInvoiceNumber() async {
    final year = DateTime.now().year;
    final month = DateTime.now().month.toString().padLeft(2, '0');

    // Get last purchase
    final purchases =
        await (db.select(db.purchases)
              ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])
              ..limit(1))
            .get();

    int nextNum = 1;
    if (purchases.isNotEmpty) {
      final lastNumber = purchases.first.invoiceNumber;
      if (lastNumber != null && lastNumber.contains('PU$year')) {
        try {
          final parts = lastNumber.split('-');
          nextNum = int.parse(parts.last) + 1;
        } catch (_) {}
      }
    }

    return 'PU$year$month-${nextNum.toString().padLeft(4, '0')}';
  }
}

// ==================== DATA CLASSES ====================

class PurchaseItemCalculated {
  final String productId;
  final double quantity;
  final double unitFactor;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final double taxPercent;

  PurchaseItemCalculated({
    required this.productId,
    required this.quantity,
    required this.unitFactor,
    required this.unitPrice,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.taxPercent = 0,
  });

  double get baseQuantity => PurchaseService.calculateBaseQuantity(
    quantity: quantity,
    unitFactor: unitFactor,
  );

  double get subtotal => PurchaseService.calculateSubtotal(
    quantity: quantity,
    unitPrice: unitPrice,
  );

  double get discount => PurchaseService.calculateDiscount(
    subtotal: subtotal,
    discountPercent: discountPercent,
    discountAmount: discountAmount,
  );

  double get tax => PurchaseService.calculateTax(
    amountAfterDiscount: subtotal - discount,
    taxPercent: taxPercent,
  );
}

class PurchaseTotals {
  final double subtotal;
  final double discount;
  final double tax;
  final double shippingCost;
  final double otherExpenses;
  final double landedCosts;
  final double grandTotal;

  PurchaseTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.shippingCost,
    required this.otherExpenses,
    required this.landedCosts,
    required this.grandTotal,
  });
}

class CostDistributionItem {
  final String productId;
  final double baseQuantity;
  final double subtotal;

  CostDistributionItem({
    required this.productId,
    required this.baseQuantity,
    required this.subtotal,
  });
}

class CostDistribution {
  final String productId;
  final double costShare;

  CostDistribution({required this.productId, required this.costShare});
}

class SupplierPaymentLink {
  final String purchaseId;
  final double amount;

  SupplierPaymentLink({required this.purchaseId, required this.amount});
}
