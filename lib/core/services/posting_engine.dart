import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:uuid/uuid.dart';

enum OperationType {
  sale,
  purchase,
  salesReturn,
  purchaseReturn,
  customerPayment,
  supplierPayment,
  expense,
  inventoryAdjustment,
  stockTransfer,
  damage,
}

enum AccountType {
  cash,
  bank,
  receivable,
  payable,
  inventory,
  revenue,
  cogs,
  taxInput,
  taxOutput,
  expense,
  costCenter,
}

class CostCenterDistribution {
  final String costCenterId;
  final double percentage; // 0.0 to 1.0
  final double? amount; // Optional fixed amount

  CostCenterDistribution({
    required this.costCenterId,
    this.percentage = 1.0,
    this.amount,
  });
}

class PostingContext {
  final OperationType operationType;
  final String? referenceId;
  final String? referenceType;
  final DateTime date;
  final String description;
  final String? customerId;
  final String? supplierId;
  final double total;
  final double tax;
  final double cost;
  final bool isCredit;
  final String? paymentMethod;

  final String? currencyId;
  final double exchangeRate;
  final double? baseCurrencyRate;
  final List<PostingItem> items;
  final String? costCenterId;
  final List<CostCenterDistribution> distributions;

  PostingContext({
    required this.operationType,
    this.referenceId,
    this.referenceType,
    required this.date,
    required this.description,
    this.customerId,
    this.supplierId,
    required this.total,
    required this.tax,
    required this.cost,
    required this.isCredit,
    this.paymentMethod,
    this.currencyId,
    this.exchangeRate = 1.0,
    this.baseCurrencyRate,
    this.items = const [],
    this.costCenterId,
    this.distributions = const [],
  });

  double get baseAmount => total * exchangeRate;
  double get baseTax => tax * exchangeRate;
  double get baseCost => cost * exchangeRate;
}

class PostingItem {
  final String productId;
  final double quantity;
  final double unitPrice;
  final double cost;

  PostingItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.cost = 0,
  });
}

class PostingRule {
  final String id;
  final String operationType;
  final String accountType;
  final String? accountId;
  final String? accountCode;
  final String side;
  final int sequence;
  final String? description;
  final bool isActive;

  PostingRule({
    required this.id,
    required this.operationType,
    required this.accountType,
    this.accountId,
    this.accountCode,
    required this.side,
    required this.sequence,
    this.description,
    this.isActive = true,
  });
}

class PostingEngine {
  final AppDatabase db;
  late final AuditService _auditService;
  final bool useConfigDriven;

  PostingEngine(this.db, {this.useConfigDriven = true}) {
    _auditService = AuditService(db);
  }

  static const Map<String, String> _accountCodeDefaults = {
    'cash': '1010',
    'bank': '1020',
    'receivable': '1030',
    'payable': '2010',
    'inventory': '1040',
    'revenue': '4010',
    'cogs': '5010',
    'taxInput': '1050',
    'taxOutput': '2020',
    'expense': '6000',
  };

  String _getDefaultAccountCode(String accountType) {
    return _accountCodeDefaults[accountType] ??
        _accountCodeDefaults['EXPENSE']!;
  }

  Future<String?> _resolveAccountId(
    PostingRule rule,
    PostingContext context,
  ) async {
    if (rule.accountId != null) {
      return rule.accountId;
    }

    if (rule.accountCode != null) {
      final account = await db.accountingDao.getAccountByCode(
        rule.accountCode!,
      );
      return account?.id;
    }

    String? targetCode;
    switch (rule.accountType) {
      case 'cash':
        if (context.paymentMethod == 'bank') {
          targetCode = _getDefaultAccountCode('bank');
        } else {
          targetCode = _getDefaultAccountCode('cash');
        }
        break;
      case 'receivable':
        if (context.customerId != null) {
          final customer = await db.customersDao.getCustomerById(
            context.customerId!,
          );
          return customer?.accountId;
        }
        targetCode = _getDefaultAccountCode('receivable');
        break;
      case 'payable':
        if (context.supplierId != null) {
          final supplier = await db.suppliersDao.getSupplierById(
            context.supplierId!,
          );
          return supplier?.accountId;
        }
        targetCode = _getDefaultAccountCode('payable');
        break;
      default:
        targetCode = _getDefaultAccountCode(rule.accountType);
    }

    final account = await db.accountingDao.getAccountByCode(targetCode);
    return account?.id;
  }

  Future<List<PostingRule>> _getRulesForOperation(
    OperationType operationType,
  ) async {
    final operationName = operationType.name;

    if (!useConfigDriven) {
      return _getDefaultRules(operationName);
    }

    try {
      final profiles =
          await (db.select(db.postingProfiles)
                ..where((p) => p.operationType.equals(operationName))
                ..where((p) => p.isActive.equals(true))
                ..orderBy([
                  (p) => OrderingTerm(
                    expression: p.sequence,
                    mode: OrderingMode.asc,
                  ),
                ]))
              .get();

      return profiles
          .map(
            (p) => PostingRule(
              id: p.id,
              operationType: p.operationType,
              accountType: p.accountType,
              accountId: p.accountId,
              accountCode: p.accountCode,
              side: p.side,
              sequence: p.sequence,
              description: p.description,
              isActive: p.isActive,
            ),
          )
          .toList();
    } catch (e) {
      return _getDefaultRules(operationName);
    }
  }

  List<PostingRule> _getDefaultRules(String operationType) {
    switch (operationType) {
      case 'sale':
        return [
          PostingRule(
            id: '1',
            operationType: 'sale',
            accountType: 'receivable',
            side: 'DEBIT',
            sequence: 1,
          ),
          PostingRule(
            id: '2',
            operationType: 'sale',
            accountType: 'revenue',
            side: 'CREDIT',
            sequence: 2,
          ),
          PostingRule(
            id: '3',
            operationType: 'sale',
            accountType: 'taxOutput',
            side: 'CREDIT',
            sequence: 3,
          ),
        ];
      case 'purchase':
        return [
          PostingRule(
            id: '1',
            operationType: 'purchase',
            accountType: 'inventory',
            side: 'DEBIT',
            sequence: 1,
          ),
          PostingRule(
            id: '2',
            operationType: 'purchase',
            accountType: 'taxInput',
            side: 'DEBIT',
            sequence: 2,
          ),
          PostingRule(
            id: '3',
            operationType: 'purchase',
            accountType: 'payable',
            side: 'CREDIT',
            sequence: 3,
          ),
        ];
      case 'salesReturn':
        return [
          PostingRule(
            id: '1',
            operationType: 'salesReturn',
            accountType: 'revenue',
            side: 'DEBIT',
            sequence: 1,
          ),
          PostingRule(
            id: '2',
            operationType: 'salesReturn',
            accountType: 'taxOutput',
            side: 'DEBIT',
            sequence: 2,
          ),
          PostingRule(
            id: '3',
            operationType: 'salesReturn',
            accountType: 'receivable',
            side: 'CREDIT',
            sequence: 3,
          ),
        ];
      case 'purchaseReturn':
        return [
          PostingRule(
            id: '1',
            operationType: 'purchaseReturn',
            accountType: 'payable',
            side: 'DEBIT',
            sequence: 1,
          ),
          PostingRule(
            id: '2',
            operationType: 'purchaseReturn',
            accountType: 'expense',
            side: 'CREDIT',
            sequence: 2,
          ),
          PostingRule(
            id: '3',
            operationType: 'purchaseReturn',
            accountType: 'taxInput',
            side: 'CREDIT',
            sequence: 3,
          ),
        ];
      case 'expense':
        return [
          PostingRule(
            id: '1',
            operationType: 'expense',
            accountType: 'expense',
            side: 'DEBIT',
            sequence: 1,
          ),
          PostingRule(
            id: '2',
            operationType: 'expense',
            accountType: 'cash',
            side: 'CREDIT',
            sequence: 2,
          ),
        ];
      case 'damage':
        return [
          PostingRule(
            id: '1',
            operationType: 'damage',
            accountType: 'expense',
            side: 'DEBIT',
            sequence: 1,
          ),
          PostingRule(
            id: '2',
            operationType: 'damage',
            accountType: 'inventory',
            side: 'CREDIT',
            sequence: 2,
          ),
        ];
      default:
        return [];
    }
  }

  double _calculateAmount(PostingRule rule, PostingContext context) {
    switch (rule.accountType) {
      case 'revenue':
        return context.tax > 0 ? context.total - context.tax : context.total;
      case 'taxOutput':
      case 'taxInput':
        return context.tax;
      case 'cogs':
        return context.cost;
      case 'inventory':
        return context.tax > 0 ? context.total - context.tax : context.total;
      default:
        return context.total;
    }
  }

  Future<void> _validateBalancing(List<GLLinesCompanion> lines) async {
    double totalDebit = 0;
    double totalCredit = 0;

    for (var line in lines) {
      totalDebit += line.debit.value;
      totalCredit += line.credit.value;
    }

    final difference = (totalDebit - totalCredit).abs();
    if (difference > 0.01) {
      throw Exception(
        'خلل في الترحيل: Debit ($totalDebit) لا يساوي Credit ($totalCredit)',
      );
    }
  }

  Future<void> _validateAccountingPeriod(DateTime postingDate) async {
    final openPeriod =
        await (db.select(db.accountingPeriods)
              ..where((p) => p.isClosed.equals(false))
              ..where((p) => p.startDate.isSmallerOrEqualValue(postingDate))
              ..where((p) => p.endDate.isBiggerOrEqualValue(postingDate)))
            .getSingleOrNull();

    if (openPeriod == null) {
      throw Exception(
        'لا توجد فترة محاسبية مفتوحة للتاريخ: ${postingDate.toLocal().toString().split(' ')[0]}',
      );
    }
  }

  Future<void> _validateCostCenter(String? costCenterId) async {
    if (costCenterId == null) return;

    final costCenter =
        await (db.select(db.costCenters)
              ..where((c) => c.id.equals(costCenterId))
              ..where((c) => c.isActive.equals(true)))
            .getSingleOrNull();

    if (costCenter == null) {
      throw Exception('مركز التكلفة غير موجود أو غير نشط');
    }
  }

  Future<GLEntry> generateEntry({
    required PostingContext context,
    bool skipValidation = false,
    bool skipAudit = false,
  }) async {
    final rules = await _getRulesForOperation(context.operationType);

    if (rules.isEmpty) {
      throw Exception(
        'لا توجد قواعد ترحيل للنوع: ${context.operationType.name}',
      );
    }

    if (!skipValidation) {
      await _validateAccountingPeriod(context.date);
      await _validateCostCenter(context.costCenterId);
    }

    final entryId = const Uuid().v4();
    final lines = <GLLinesCompanion>[];

    for (var rule in rules) {
      final accountId = await _resolveAccountId(rule, context);

      if (accountId == null) {
        throw Exception('الحساب غير موجود: ${rule.accountType}');
      }

      final amount = _calculateAmount(rule, context);

      if (amount <= 0 &&
          rule.accountType != 'cogs' &&
          rule.accountType != 'inventory') {
        continue;
      }

      // Handle Cost Center Distribution
      if (context.distributions.isNotEmpty && 
          (rule.accountType == 'expense' || rule.accountType == 'inventory')) {
        for (var dist in context.distributions) {
          final distAmount = dist.amount ?? (amount * dist.percentage);
          if (distAmount <= 0) continue;
          
          lines.add(
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: accountId,
              debit: rule.side == 'DEBIT' ? Value(distAmount) : const Value(0.0),
              credit: rule.side == 'CREDIT' ? Value(distAmount) : const Value(0.0),
              currencyId: Value(context.currencyId),
              exchangeRate: Value(context.exchangeRate),
              costCenterId: Value(dist.costCenterId),
            ),
          );
        }
      } else {
        lines.add(
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: accountId,
            debit: rule.side == 'DEBIT' ? Value(amount) : const Value(0.0),
            credit: rule.side == 'CREDIT' ? Value(amount) : const Value(0.0),
            currencyId: Value(context.currencyId),
            exchangeRate: Value(context.exchangeRate),
            costCenterId: Value(context.costCenterId),
          ),
        );
      }
    }

    if (!skipValidation) {
      await _validateBalancing(lines);
    }

    return await _createEntryAndLines(entryId, lines, context, skipAudit);
  }

  Future<GLEntry> _createEntryAndLines(
    String entryId,
    List<GLLinesCompanion> lines,
    PostingContext context,
    bool skipAudit,
  ) async {
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context.description,
      date: Value(context.date),
      referenceType: Value(context.referenceType ?? context.operationType.name),
      referenceId: Value(context.referenceId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
      currencyId: Value(context.currencyId),
      exchangeRate: Value(context.exchangeRate),
    );

    await db.accountingDao.createEntry(entry, lines);

    if (!skipAudit) {
      await _auditService.logCreate(
        'GLEntry',
        entryId,
        details:
            'تم الترحيل عبر Posting Engine: ${context.operationType.name} - ${context.description}',
      );
    }

    final createdEntry = await (db.select(
      db.gLEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();

    return createdEntry;
  }

  Future<GLEntry> generateCogsEntry({
    required PostingContext context,
    String? saleId,
  }) async {
    if (context.cost <= 0) {
      throw Exception('التكلفة صفر، لا حاجة لقيد تكلفة البضاعة المباعة');
    }

    final entryId = const Uuid().v4();

    final cogsAccount = await db.accountingDao.getAccountByCode(
      _accountCodeDefaults['COGS']!,
    );
    final inventoryAccount = await db.accountingDao.getAccountByCode(
      _accountCodeDefaults['INVENTORY']!,
    );

    if (cogsAccount == null || inventoryAccount == null) {
      throw Exception('حساب تكلفة البضاعة أو المخزون غير موجود');
    }

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: cogsAccount.id,
        debit: Value(context.cost),
        credit: const Value(0.0),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: inventoryAccount.id,
        debit: const Value(0.0),
        credit: Value(context.cost),
      ),
    ];

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'تكلفة البضاعة المباعة - ${context.description}',
      date: Value(context.date),
      referenceType: const Value('COGS'),
      referenceId: Value(saleId),
      status: const Value('POSTED'),
      postedAt: Value(DateTime.now()),
    );

    await db.accountingDao.createEntry(entry, lines);

    await _auditService.logCreate(
      'GLEntry',
      entryId,
      details: ' قيد تكلفة البضاعة المباعة',
    );

    final createdEntry = await (db.select(
      db.gLEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();

    return createdEntry;
  }

  Future<void> seedDefaultPostingProfiles() async {
    if (!useConfigDriven) return;

    try {
      final existingProfiles = await db.select(db.postingProfiles).get();
      if (existingProfiles.isNotEmpty) return;
    } catch (e) {
      return;
    }

    final defaultProfiles = [
      PostingProfilesCompanion.insert(
        id: Value(const Uuid().v4()),
        operationType: 'SALE',
        accountType: 'RECEIVABLE',
        accountCode: const Value('1030'),
        side: 'DEBIT',
        sequence: const Value(1),
        syncStatus: const Value(1),
      ),
      PostingProfilesCompanion.insert(
        id: Value(const Uuid().v4()),
        operationType: 'SALE',
        accountType: 'REVENUE',
        accountCode: const Value('4010'),
        side: 'CREDIT',
        sequence: const Value(2),
        syncStatus: const Value(1),
      ),
      PostingProfilesCompanion.insert(
        id: Value(const Uuid().v4()),
        operationType: 'SALE',
        accountType: 'TAX_OUTPUT',
        accountCode: const Value('2020'),
        side: 'CREDIT',
        sequence: const Value(3),
        syncStatus: const Value(1),
      ),
      PostingProfilesCompanion.insert(
        id: Value(const Uuid().v4()),
        operationType: 'PURCHASE',
        accountType: 'INVENTORY',
        accountCode: const Value('1040'),
        side: 'DEBIT',
        sequence: const Value(1),
        syncStatus: const Value(1),
      ),
      PostingProfilesCompanion.insert(
        id: Value(const Uuid().v4()),
        operationType: 'PURCHASE',
        accountType: 'TAX_INPUT',
        accountCode: const Value('1050'),
        side: 'DEBIT',
        sequence: const Value(2),
        syncStatus: const Value(1),
      ),
      PostingProfilesCompanion.insert(
        id: Value(const Uuid().v4()),
        operationType: 'PURCHASE',
        accountType: 'PAYABLE',
        accountCode: const Value('2010'),
        side: 'CREDIT',
        sequence: const Value(3),
        syncStatus: const Value(1),
      ),
    ];

    for (var profile in defaultProfiles) {
      try {
        await db.into(db.postingProfiles).insert(profile);
      } catch (e) {
        // Skip if table doesn't exist yet
      }
    }
  }
}
