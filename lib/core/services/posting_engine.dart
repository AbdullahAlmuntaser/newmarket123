import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';
import 'app_config_service.dart';

class PostingLine {
  final String account;
  final Decimal debit;
  final Decimal credit;
  PostingLine({
    required this.account,
    required this.debit,
    required this.credit,
  });
}

class PostingEngine {
  static final Decimal balanceTolerance = Decimal.parse('0.001');

  final AppDatabase db;
  final InventoryCostingService? costingService;
  late final AppConfigService _configService;

  PostingEngine(this.db, {this.costingService}) {
    _configService = AppConfigService(db);
  }

  /// Main posting method - single source of truth for all GL entries.
  /// Routes to specific handlers based on transaction type.
  Future<void> post({
    required TransactionType type,
    required String referenceId,
    required Map<String, dynamic> context,
  }) async {
    await _checkPeriodOpen(context['date'] as DateTime?);

    switch (type) {
      case TransactionType.sale:
        await _postSale(referenceId, context);
        break;
      case TransactionType.purchase:
        await _postPurchase(referenceId, context);
        break;
      case TransactionType.saleReturn:
        await _postSaleReturn(referenceId, context);
        break;
      case TransactionType.purchaseReturn:
        await _postPurchaseReturn(referenceId, context);
        break;
      case TransactionType.customerPayment:
        await _postCustomerPayment(referenceId, context);
        break;
      case TransactionType.supplierPayment:
        await _postSupplierPayment(referenceId, context);
        break;
      case TransactionType.cashReceipt:
      case TransactionType.cashPayment:
        await _postCashTransaction(referenceId, context);
        break;
      default:
        await _postGeneric(referenceId, context);
    }
  }

  Future<void> _postSale(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final tax = _readAmount(context['tax']);
    final cogs = _readAmount(context['cogs']);
    final paymentMethod = context['paymentMethod'] as String? ?? 'cash';
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    // Use posting profiles if available, otherwise use hardcoded defaults
    final profiles = await _getPostingProfiles('SALE');

    String debitAccountId;
    if (paymentMethod == 'credit') {
      debitAccountId =
          await _getAccountByProfileOrCode(profiles, 'RECEIVABLE', '1030');
    } else {
      debitAccountId =
          await _getAccountByProfileOrCode(profiles, 'CASH', '1010');
    }
    final revenueAccount =
        await _getAccountByProfileOrCode(profiles, 'REVENUE', '4010');
    final taxAccount =
        await _getAccountByProfileOrCode(profiles, 'OUTPUT_VAT', '2020');

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description:
          context['description'] ?? 'Sale #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: const Value('SALE'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: debitAccountId,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: revenueAccount,
        debit: Value(Decimal.zero),
        credit: Value(amount - tax),
        branchId: Value(branchId),
      ),
      if (tax > Decimal.zero)
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: taxAccount,
          debit: Value(Decimal.zero),
          credit: Value(tax),
          branchId: Value(branchId),
        ),
    ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);

    // COGS entry
    if (cogs > Decimal.zero) {
      final cogsEntryId = const Uuid().v4();
      final cogsAccount =
          await _getAccountByProfileOrCode(profiles, 'COGS', '5010');
      final inventoryAccount =
          await _getAccountByProfileOrCode(profiles, 'INVENTORY', '1040');

      final cogsEntry = GLEntriesCompanion.insert(
        id: Value(cogsEntryId),
        description: 'COGS for #${referenceId.substring(0, 8)}',
        date: Value(date),
        referenceType: const Value('COGS'),
        referenceId: Value(referenceId),
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
        branchId: Value(branchId),
      );
      final cogsLines = [
        GLLinesCompanion.insert(
          entryId: cogsEntryId,
          accountId: cogsAccount,
          debit: Value(cogs),
          credit: Value(Decimal.zero),
          branchId: Value(branchId),
        ),
        GLLinesCompanion.insert(
          entryId: cogsEntryId,
          accountId: inventoryAccount,
          debit: Value(Decimal.zero),
          credit: Value(cogs),
          branchId: Value(branchId),
        ),
      ];
      validatePostingLinesRaw(cogsLines);
      await dao.createEntry(cogsEntry, cogsLines);
    }
  }

  Future<void> _postPurchase(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final tax = _readAmount(context['tax']);
    final paymentMethod = context['paymentMethod'] as String? ?? 'cash';
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    final profiles = await _getPostingProfiles('PURCHASE');

    final inventoryAccount =
        await _getAccountByProfileOrCode(profiles, 'INVENTORY', '1040');
    final taxAccount =
        await _getAccountByProfileOrCode(profiles, 'INPUT_VAT', '1050');

    String creditAccountId;
    if (paymentMethod == 'credit') {
      creditAccountId =
          await _getAccountByProfileOrCode(profiles, 'PAYABLE', '2010');
    } else {
      creditAccountId =
          await _getAccountByProfileOrCode(profiles, 'CASH', '1010');
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description:
          context['description'] ?? 'Purchase #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: const Value('PURCHASE'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final inventoryValue = amount - tax;
    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: inventoryAccount,
        debit: Value(inventoryValue),
        credit: Value(Decimal.zero),
        branchId: Value(branchId),
      ),
      if (tax > Decimal.zero)
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: taxAccount,
          debit: Value(tax),
          credit: Value(Decimal.zero),
          branchId: Value(branchId),
        ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: creditAccountId,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        branchId: Value(branchId),
      ),
    ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);
  }

  Future<void> _postSaleReturn(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final paymentMethod = context['paymentMethod'] as String? ?? 'cash';
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    final profiles = await _getPostingProfiles('SALE_RETURN');
    final returnAccount =
        await _getAccountByProfileOrCode(profiles, 'RETURN', '4020');

    String creditAccountId;
    if (paymentMethod == 'credit') {
      creditAccountId =
          await _getAccountByProfileOrCode(profiles, 'RECEIVABLE', '1030');
    } else {
      creditAccountId =
          await _getAccountByProfileOrCode(profiles, 'CASH', '1010');
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ??
          'Sale Return #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: const Value('SALE_RETURN'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: returnAccount,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: creditAccountId,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        branchId: Value(branchId),
      ),
    ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);
  }

  Future<void> _postPurchaseReturn(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final paymentMethod = context['paymentMethod'] as String? ?? 'cash';
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    final profiles = await _getPostingProfiles('PURCHASE_RETURN');
    final returnAccount =
        await _getAccountByProfileOrCode(profiles, 'RETURN', '5011');

    String debitAccountId;
    if (paymentMethod == 'credit') {
      debitAccountId =
          await _getAccountByProfileOrCode(profiles, 'PAYABLE', '2010');
    } else {
      debitAccountId =
          await _getAccountByProfileOrCode(profiles, 'CASH', '1010');
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ??
          'Purchase Return #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: const Value('PURCHASE_RETURN'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: debitAccountId,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: returnAccount,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        branchId: Value(branchId),
      ),
    ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);
  }

  Future<void> _postCustomerPayment(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final customerId = context['customerId'] as String?;
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    final profiles = await _getPostingProfiles('CUSTOMER_PAYMENT');
    final cashAccount =
        await _getAccountByProfileOrCode(profiles, 'CASH', '1010');
    final arAccount =
        await _getAccountByProfileOrCode(profiles, 'RECEIVABLE', '1030');

    String customerAccountId = arAccount;
    if (customerId != null) {
      final customer = await db.customersDao.getCustomerById(customerId);
      if (customer?.accountId != null) {
        customerAccountId = customer!.accountId!;
      }
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ??
          'Customer Payment #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: const Value('RECEIPT'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: cashAccount,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: customerAccountId,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        branchId: Value(branchId),
      ),
    ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);
  }

  Future<void> _postSupplierPayment(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final supplierId = context['supplierId'] as String?;
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    final profiles = await _getPostingProfiles('SUPPLIER_PAYMENT');
    final apAccount =
        await _getAccountByProfileOrCode(profiles, 'PAYABLE', '2010');
    final cashAccount =
        await _getAccountByProfileOrCode(profiles, 'CASH', '1010');

    String supplierAccountId = apAccount;
    if (supplierId != null) {
      final supplier = await db.suppliersDao.getSupplierById(supplierId);
      if (supplier?.accountId != null) {
        supplierAccountId = supplier!.accountId!;
      }
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ??
          'Supplier Payment #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: const Value('PAYMENT'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: supplierAccountId,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: cashAccount,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        branchId: Value(branchId),
      ),
    ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);
  }

  Future<void> _postCashTransaction(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final accountId = context['accountId'] as String?;
    final direction = context['cashDirection'] as String? ?? 'IN';
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    final profiles = await _getPostingProfiles('CASH_TRANSACTION');
    final cashAccount =
        await _getAccountByProfileOrCode(profiles, 'CASH', '1010');

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ??
          'Cash Transaction #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: Value(direction == 'IN' ? 'RECEIPT' : 'PAYMENT'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final lines = direction == 'IN'
        ? [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: cashAccount,
              debit: Value(amount),
              credit: Value(Decimal.zero),
              branchId: Value(branchId),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: accountId ?? cashAccount,
              debit: Value(Decimal.zero),
              credit: Value(amount),
              branchId: Value(branchId),
            ),
          ]
        : [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: accountId ?? cashAccount,
              debit: Value(amount),
              credit: Value(Decimal.zero),
              branchId: Value(branchId),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: cashAccount,
              debit: Value(Decimal.zero),
              credit: Value(amount),
              branchId: Value(branchId),
            ),
          ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);
  }

  Future<void> _postGeneric(
      String referenceId, Map<String, dynamic> context) async {
    final dao = db.accountingDao;
    final amount = _readAmount(context['amount']);
    final branchId = context['branchId'] as String? ??
        await _configService.getDefaultBranchId();
    final date = context['date'] as DateTime? ?? DateTime.now();
    final entryId = const Uuid().v4();

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ??
          'Transaction #${referenceId.substring(0, 8)}',
      date: Value(date),
      referenceType: Value(context['referenceType'] as String? ?? 'GENERIC'),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: context['debitAccountId'] as String? ?? '',
        debit: Value(amount),
        credit: Value(Decimal.zero),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: context['creditAccountId'] as String? ?? '',
        debit: Value(Decimal.zero),
        credit: Value(amount),
        branchId: Value(branchId),
      ),
    ];
    validatePostingLinesRaw(lines);
    await dao.createEntry(entry, lines);
  }

  /// Resolves account ID from posting profiles or falls back to hardcoded code.
  Future<String> _getAccountByProfileOrCode(
    List<PostingProfile> profiles,
    String accountType,
    String defaultCode,
  ) async {
    // First try to find a matching posting profile entry
    for (final profile in profiles) {
      if (profile.accountType.toUpperCase() == accountType.toUpperCase()) {
        if (profile.accountId != null && profile.accountId!.isNotEmpty) {
          return profile.accountId!;
        }
      }
    }
    // Fall back to account code lookup
    final account = await db.accountingDao.getAccountByCode(defaultCode);
    if (account != null) return account.id;
    throw Exception('لم يتم العثور على حساب محاسبي للكود: $defaultCode');
  }

  /// Gets posting profiles for a given operation type.
  Future<List<PostingProfile>> _getPostingProfiles(String operationType) async {
    final profiles = await (db.select(db.postingProfiles)
          ..where((p) => p.operationType.equals(operationType.toUpperCase()))
          ..where((p) => p.isActive.equals(true)))
        .get();
    return profiles;
  }

  Future<void> postEntry({
    required List<PostingLine> entries,
    required String reference,
    required DateTime date,
  }) async {
    await _checkPeriodOpen(date);
    validatePostingLines(entries);

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'Transaction: $reference',
      date: Value(date),
      referenceId: Value(reference),
      status: const Value('POSTED'),
    );

    final lines = entries
        .map(
          (e) => GLLinesCompanion.insert(
            entryId: entryId,
            accountId: e.account,
            debit: Value(e.debit),
            credit: Value(e.credit),
          ),
        )
        .toList();

    await db.accountingDao.createEntry(entry, lines);
  }

  static void validatePostingLines(List<PostingLine> entries) {
    if (entries.isEmpty) {
      throw Exception('لا يمكن الترحيل بدون قيود محاسبية.');
    }

    var totalDebit = Decimal.zero;
    var totalCredit = Decimal.zero;

    for (final entry in entries) {
      if (entry.account.trim().isEmpty) {
        throw Exception('الحساب المحاسبي غير محدد.');
      }
      if (entry.debit < Decimal.zero || entry.credit < Decimal.zero) {
        throw Exception('المبلغ يجب أن يكون أكبر من أو يساوي الصفر.');
      }
      if (entry.debit > Decimal.zero && entry.credit > Decimal.zero) {
        throw Exception('لا يمكن أن يكون السطر مديناً ودائناً في نفس الوقت.');
      }
      if (entry.debit == Decimal.zero && entry.credit == Decimal.zero) {
        throw Exception('لا يمكن ترحيل سطر محاسبي بقيمة صفرية.');
      }
      totalDebit += entry.debit;
      totalCredit += entry.credit;
    }

    if ((totalDebit - totalCredit).abs() > balanceTolerance) {
      throw Exception(
        'القيد المحاسبي غير متوازن! (المدين: $totalDebit، الدائن: $totalCredit)',
      );
    }
  }

  static void validatePostingLinesRaw(List<GLLinesCompanion> lines) {
    if (lines.isEmpty) {
      throw Exception('لا يمكن الترحيل بدون قيود محاسبية.');
    }
    var totalDebit = Decimal.zero;
    var totalCredit = Decimal.zero;
    for (final line in lines) {
      totalDebit += line.debit.value;
      totalCredit += line.credit.value;
    }
    if ((totalDebit - totalCredit).abs() > balanceTolerance) {
      throw Exception(
        'القيد المحاسبي غير متوازن! (المدين: $totalDebit، الدائن: $totalCredit)',
      );
    }
  }

  Future<Decimal> getTotalByAccount(
    String accountId,
    DateTime from,
    DateTime to,
  ) async {
    final entriesInRange = await (db.select(db.gLEntries)
          ..where((e) => e.date.isBiggerOrEqual(Variable(from)))
          ..where((e) => e.date.isSmallerOrEqual(Variable(to))))
        .get();
    if (entriesInRange.isEmpty) return Decimal.zero;
    final entryIds = entriesInRange.map((e) => e.id).toList();
    final query = db.select(db.gLLines)
      ..where((l) => l.accountId.equals(accountId))
      ..where((l) => l.entryId.isIn(entryIds));
    final results = await query.get();
    Decimal total = Decimal.zero;
    for (var line in results) {
      total += (line.debit - line.credit);
    }
    return total;
  }

  Future<Decimal> getBalanceForAccount(String accountId) async {
    final query = db.select(db.gLLines)
      ..where((l) => l.accountId.equals(accountId));
    final results = await query.get();
    Decimal total = Decimal.zero;
    for (var line in results) {
      total += (line.debit - line.credit);
    }
    return total;
  }

  Decimal _readAmount(dynamic value) {
    if (value is Decimal) return value;
    if (value is num) return Decimal.parse(value.toString());
    if (value is String) return Decimal.tryParse(value) ?? Decimal.zero;
    return Decimal.zero;
  }

  Future<void> _checkPeriodOpen([DateTime? postingDate]) async {
    final date = postingDate ?? DateTime.now();
    final period = await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..where((p) => p.startDate.isSmallerOrEqual(Variable(date)))
          ..where((p) => p.endDate.isBiggerOrEqual(Variable(date))))
        .getSingleOrNull();
    if (period == null) throw Exception('Period is locked or closed.');
  }

  Future<List<PostingLine>> getEntriesByAccount(
    String accountId,
    DateTime from,
    DateTime to,
  ) async {
    final entriesInRange = await (db.select(db.gLEntries)
          ..where((e) => e.date.isBiggerOrEqual(Variable(from)))
          ..where((e) => e.date.isSmallerOrEqual(Variable(to))))
        .get();
    if (entriesInRange.isEmpty) return [];
    final entryIds = entriesInRange.map((e) => e.id).toList();
    final query = db.select(db.gLLines)
      ..where((l) => l.accountId.equals(accountId))
      ..where((l) => l.entryId.isIn(entryIds));
    final results = await query.get();
    return results.map((line) {
      return PostingLine(
        account: line.accountId,
        debit: line.debit,
        credit: line.credit,
      );
    }).toList();
  }
}
