import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

enum DocumentStatus { draft, posted, voided }

enum VoidReason { errorInEntry, customerReturn, duplicateEntry, other }

class FinancialControlResult {
  final bool success;
  final String? error;
  final String? message;
  final String? journalEntryId;

  FinancialControlResult({
    required this.success,
    this.error,
    this.message,
    this.journalEntryId,
  });
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({required this.isValid, this.errors = const []});
}

class FinancialControlService {
  final AppDatabase db;
  late final AuditService _auditService;
  late final InventoryCostingService _inventoryCostingService;

  FinancialControlService(this.db) {
    _auditService = AuditService(db);
    _inventoryCostingService = InventoryCostingService(db.stockMovementDao);
  }

  Future<ValidationResult> validateSale(String saleId) async {
    final List<String> errors = [];

    final sale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingleOrNull();
    if (sale == null) {
      errors.add('الفاتورة غير موجودة');
      return ValidationResult(isValid: false, errors: errors);
    }

    if (sale.status == 'posted') {
      errors.add('الفاتورة مرحّلة مسبقاً');
    }
    if (sale.status == 'void') {
      errors.add('الفاتورة ملغاة');
    }

    if (sale.total <= 0) {
      errors.add('إجمالي الفاتورة يجب أن يكون أكبر من صفر');
    }

    final items = await (db.select(
      db.saleItems,
    )..where((si) => si.saleId.equals(saleId))).get();
    if (items.isEmpty) {
      errors.add('الفاتورة لا تحتوي على أصناف');
    }

    for (var item in items) {
      if (item.quantity <= 0) {
        errors.add('الكمية يجب أن تكون أكبر من صفر للمنتج');
      }
      if (item.price < 0) {
        errors.add('السعر لا يمكن أن يكون سالب');
      }
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  Future<ValidationResult> validatePurchase(String purchaseId) async {
    final List<String> errors = [];

    final purchase = await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingleOrNull();
    if (purchase == null) {
      errors.add('الفاتورة غير موجودة');
      return ValidationResult(isValid: false, errors: errors);
    }

    if (purchase.status == 'posted') {
      errors.add('الفاتورة مرحّلة مسبقاً');
    }
    if (purchase.status == 'void') {
      errors.add('الفاتورة ملغاة');
    }

    if (purchase.total <= 0) {
      errors.add('إجمالي الفاتورة يجب أن يكون أكبر من صفر');
    }

    final items = await (db.select(
      db.purchaseItems,
    )..where((pi) => pi.purchaseId.equals(purchaseId))).get();
    if (items.isEmpty) {
      errors.add('الفاتورة لا تحتوي على أصناف');
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  Future<ValidationResult> validateGLEntry(String entryId) async {
    final List<String> errors = [];

    final entry = await (db.select(
      db.gLEntries,
    )..where((e) => e.id.equals(entryId))).getSingleOrNull();
    if (entry == null) {
      errors.add('القيد غير موجود');
      return ValidationResult(isValid: false, errors: errors);
    }

    if (entry.description.isEmpty) {
      errors.add('الوصف مطلوب');
    }

    final lines = await (db.select(
      db.gLLines,
    )..where((l) => l.entryId.equals(entryId))).get();

    if (lines.isEmpty) {
      errors.add('القيد لا يحتوي على أسطر');
    }

    double totalDebit = 0;
    double totalCredit = 0;

    for (var line in lines) {
      totalDebit += line.debit;
      totalCredit += line.credit;
    }

    final difference = (totalDebit - totalCredit).abs();
    if (difference > 0.01) {
      errors.add('القيد غير متوازن - Debit: $totalDebit, Credit: $totalCredit');
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  Future<ValidationResult> validateAccountingPeriod(
    DateTime date, {
    String? periodId,
  }) async {
    final List<String> errors = [];

    if (periodId != null) {
      final period = await (db.select(
        db.accountingPeriods,
      )..where((p) => p.id.equals(periodId))).getSingleOrNull();
      if (period == null) {
        errors.add('الفترة المحاسبية غير موجودة');
      } else if (period.isClosed) {
        errors.add('الفترة المحاسبية مغلقة');
      }
    } else {
      final openPeriod = await _getOpenPeriod(date);
      if (openPeriod == null) {
        errors.add('لا توجد فترة محاسبية مفتوحة لهذا التاريخ');
      }
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  Future<AccountingPeriod?> _getOpenPeriod(DateTime date) async {
    return await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..where((p) => p.startDate.isSmallerOrEqualValue(date))
          ..where((p) => p.endDate.isBiggerOrEqualValue(date)))
        .getSingleOrNull();
  }

  Future<FinancialControlResult> postSale(
    String saleId, {
    String? userId,
  }) async {
    final validation = await validateSale(saleId);
    if (!validation.isValid) {
      return FinancialControlResult(
        success: false,
        error: validation.errors.join(', '),
      );
    }

    final sale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingle();
    final periodValidation = await validateAccountingPeriod(sale.createdAt);
    if (!periodValidation.isValid) {
      return FinancialControlResult(
        success: false,
        error: periodValidation.errors.join(', '),
      );
    }

    await _auditService.logCreate(
      'Sale',
      saleId,
      details: 'ترحيل فاتورة مبيعات',
    );

    await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(
      const SalesCompanion(status: Value('POSTED')),
    );

    return FinancialControlResult(
      success: true,
      message: 'تم ترحيل الفاتورة بنجاح',
    );
  }

  Future<FinancialControlResult> postPurchase(
    String purchaseId, {
    String? userId,
  }) async {
    final validation = await validatePurchase(purchaseId);
    if (!validation.isValid) {
      return FinancialControlResult(
        success: false,
        error: validation.errors.join(', '),
      );
    }

    final purchase = await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingle();
    final periodValidation = await validateAccountingPeriod(purchase.date);
    if (!periodValidation.isValid) {
      return FinancialControlResult(
        success: false,
        error: periodValidation.errors.join(', '),
      );
    }

    await _auditService.logCreate(
      'Purchase',
      purchaseId,
      details: 'ترحيل فاتورة مشتريات',
    );

    await (db.update(db.purchases)..where((p) => p.id.equals(purchaseId)))
        .write(const PurchasesCompanion(status: Value('POSTED')));

    return FinancialControlResult(
      success: true,
      message: 'تم ترحيل الفاتورة بنجاح',
    );
  }

  Future<FinancialControlResult> voidSale({
    required String saleId,
    required VoidReason reason,
    String? note,
    String? userId,
  }) async {
    final sale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingleOrNull();

    if (sale == null) {
      return FinancialControlResult(
        success: false,
        error: 'الفاتورة غير موجودة',
      );
    }

    if (sale.status != 'posted') {
      return FinancialControlResult(
        success: false,
        error: 'الفاتورة غير مرحّلة - لا يمكن إلغاؤها',
      );
    }

    if (sale.status == 'void') {
      return FinancialControlResult(
        success: false,
        error: 'الفاتورة ملغاة مسبقاً',
      );
    }

    final periodValidation = await validateAccountingPeriod(sale.createdAt);
    if (!periodValidation.isValid) {
      return FinancialControlResult(
        success: false,
        error: periodValidation.errors.join(', '),
      );
    }

    await db.transaction(() async {
      final items = await (db.select(
        db.saleItems,
      )..where((si) => si.saleId.equals(saleId))).get();

      for (var item in items) {
        await _inventoryCostingService.returnToInventory(
          item.productId,
          item.quantity * item.unitFactor,
          item.price, // Assuming cost is the sale price for the return
          InventoryTransactionType.saleReturn,
          transactionId: saleId,
        );
      }

      await _createReverseEntry(
        originalEntryId: null,
        description: 'إلغاء فاتورة مبيعات #${sale.id.substring(0, 8)}',
        referenceType: 'SALE_VOID',
        referenceId: saleId,
        amount: sale.total,
        date: sale.createdAt,
      );

      await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(status: const Value('VOID')),
      );

      await _auditService.logCreate(
        'Sale',
        saleId,
        details: 'إلغاء فاتورة - السبب: ${reason.name} - ملاحظة: $note',
      );
    });

    return FinancialControlResult(
      success: true,
      message: 'تم إلغاء الفاتورة بنجاح وإنشاء قيد معكوس',
    );
  }

  Future<FinancialControlResult> voidPurchase({
    required String purchaseId,
    required VoidReason reason,
    String? note,
    String? userId,
  }) async {
    final purchase = await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingleOrNull();

    if (purchase == null) {
      return FinancialControlResult(
        success: false,
        error: 'الفاتورة غير موجودة',
      );
    }

    if (purchase.status != 'posted') {
      return FinancialControlResult(
        success: false,
        error: 'الفاتورة غير مرحّلة - لا يمكن إلغاؤها',
      );
    }

    if (purchase.status == 'void') {
      return FinancialControlResult(
        success: false,
        error: 'الفاتورة ملغاة مسبقاً',
      );
    }

    final periodValidation = await validateAccountingPeriod(purchase.date);
    if (!periodValidation.isValid) {
      return FinancialControlResult(
        success: false,
        error: periodValidation.errors.join(', '),
      );
    }

    await db.transaction(() async {
      final items = await (db.select(
        db.purchaseItems,
      )..where((pi) => pi.purchaseId.equals(purchaseId))).get();

      for (var item in items) {
        await _inventoryCostingService.deductFromInventory(
          item.productId,
          item.quantity,
          InventoryTransactionType.purchaseReturn,
          transactionId: purchaseId,
        );
      }

      await _createReverseEntry(
        originalEntryId: null,
        description: 'إلغاء فاتورة مشتريات #${purchase.id.substring(0, 8)}',
        referenceType: 'PURCHASE_VOID',
        referenceId: purchaseId,
        amount: purchase.total,
        date: purchase.date,
        isPurchase: true,
      );

      await (db.update(db.purchases)..where((p) => p.id.equals(purchaseId)))
          .write(PurchasesCompanion(status: const Value('VOID')));

      await _auditService.logCreate(
        'Purchase',
        purchaseId,
        details: 'إلغاء فاتورة - السبب: ${reason.name} - ملاحظة: $note',
      );
    });

    return FinancialControlResult(
      success: true,
      message: 'تم إلغاء الفاتورة بنجاح',
    );
  }

  Future<String> _createReverseEntry({
    String? originalEntryId,
    required String description,
    required String referenceType,
    required String referenceId,
    required double amount,
    required DateTime date,
    bool isPurchase = false,
  }) async {
    final entryId = const Uuid().v4();

    final arAccount = await db.accountingDao.getAccountByCode('1030');
    final apAccount = await db.accountingDao.getAccountByCode('2010');
    final revenueAccount = await db.accountingDao.getAccountByCode('4010');
    final expenseAccount = await db.accountingDao.getAccountByCode('5010');
    final cashAccount = await db.accountingDao.getAccountByCode('1010');

    if (arAccount == null ||
        apAccount == null ||
        revenueAccount == null ||
        expenseAccount == null ||
        cashAccount == null) {
      throw Exception('بعض الحسابات المطلوبة غير موجودة');
    }

    GLLinesCompanion line1;
    GLLinesCompanion line2;

    if (isPurchase) {
      line1 = GLLinesCompanion.insert(
        entryId: entryId,
        accountId: apAccount.id,
        debit: Value(amount),
        credit: const Value(0.0),
      );
      line2 = GLLinesCompanion.insert(
        entryId: entryId,
        accountId: cashAccount.id,
        debit: const Value(0.0),
        credit: Value(amount),
      );
    } else {
      line1 = GLLinesCompanion.insert(
        entryId: entryId,
        accountId: cashAccount.id,
        debit: Value(amount),
        credit: const Value(0.0),
      );
      line2 = GLLinesCompanion.insert(
        entryId: entryId,
        accountId: arAccount.id,
        debit: const Value(0.0),
        credit: Value(amount),
      );
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: description,
      date: Value(date),
      referenceType: Value(referenceType),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
    );

    await db.accountingDao.createEntry(entry, [line1, line2]);

    return entryId;
  }

  Future<FinancialControlResult> closeAccountingPeriod(
    String periodId, {
    String? note,
  }) async {
    final period = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.id.equals(periodId))).getSingleOrNull();

    if (period == null) {
      return FinancialControlResult(success: false, error: 'الفترة غير موجودة');
    }

    if (period.isClosed) {
      return FinancialControlResult(
        success: false,
        error: 'الفترة مغلقة مسبقاً',
      );
    }

    await (db.update(db.accountingPeriods)..where((p) => p.id.equals(periodId)))
        .write(const AccountingPeriodsCompanion(isClosed: Value(true)));

    await _auditService.logCreate(
      'AccountingPeriod',
      periodId,
      details:
          'إقفال الفترة المحاسبية: ${period.name}${note != null ? ' - $note' : ''}',
    );

    return FinancialControlResult(
      success: true,
      message: 'تم إقفال الفترة بنجاح',
    );
  }

  Future<FinancialControlResult> openAccountingPeriod({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final existingOpen = await (db.select(
      db.accountingPeriods,
    )..where((p) => p.isClosed.equals(false))).getSingleOrNull();

    if (existingOpen != null) {
      return FinancialControlResult(
        success: false,
        error:
            'توجد فترة مفتوحة سابقة: ${existingOpen.name}. يرجى إقفالها أولاً.',
      );
    }

    if (startDate.isAfter(endDate)) {
      return FinancialControlResult(
        success: false,
        error: 'تاريخ البداية يجب أن يكون قبل تاريخ النهاية',
      );
    }

    final periodId = const Uuid().v4();
    await db
        .into(db.accountingPeriods)
        .insert(
          AccountingPeriodsCompanion.insert(
            id: Value(periodId),
            name: name,
            startDate: startDate,
            endDate: endDate,
            isClosed: const Value(false),
            syncStatus: const Value(1),
          ),
        );

    await _auditService.logCreate(
      'AccountingPeriod',
      periodId,
      details: 'فتح فترة محاسبية جديدة: $name',
    );

    return FinancialControlResult(
      success: true,
      message: 'تم فتح الفترة بنجاح',
    );
  }

  Future<bool> canEditSale(String saleId) async {
    final sale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingleOrNull();
    return sale != null && sale.status == 'draft';
  }

  Future<bool> canEditPurchase(String purchaseId) async {
    final purchase = await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId))).getSingleOrNull();
    return purchase != null && purchase.status == 'draft';
  }

  Future<bool> canEditGLEntry(String entryId) async {
    final entry = await (db.select(
      db.gLEntries,
    )..where((e) => e.id.equals(entryId))).getSingleOrNull();
    return entry != null && entry.status == 'draft';
  }

  Future<bool> canDeleteSale(String saleId) async {
    return await canEditSale(saleId);
  }

  Future<bool> canDeletePurchase(String purchaseId) async {
    return await canEditPurchase(purchaseId);
  }

  Future<List<Map<String, dynamic>>> getAuditTrail({
    String? entityType,
    String? entityId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = db.select(db.auditLogs);

    if (entityType != null) {
      query = query..where((l) => l.targetEntity.equals(entityType));
    }
    if (entityId != null) {
      query = query..where((l) => l.entityId.equals(entityId));
    }
    if (startDate != null) {
      query = query..where((l) => l.timestamp.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query = query..where((l) => l.timestamp.isSmallerOrEqualValue(endDate));
    }

    query = query
      ..orderBy([
        (l) => OrderingTerm(expression: l.timestamp, mode: OrderingMode.desc),
      ]);

    final logs = await query.get();

    return logs
        .map(
          (log) => {
            'id': log.id,
            'entityType': log.targetEntity,
            'entityId': log.entityId,
            'action': log.action,
            'details': log.details,
            'timestamp': log.timestamp.toIso8601String(),
            'userId': log.userId,
          },
        )
        .toList();
  }
}
