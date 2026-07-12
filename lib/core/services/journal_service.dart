import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/constants/account_codes.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class JournalService {
  final AppDatabase db;
  late final AuditService _auditService;
  late final AppConfigService _configService;

  JournalService(this.db) {
    _auditService = AuditService(db);
    _configService = AppConfigService(db);
  }

  Future<void> recordExpense({
    required String description,
    required Decimal amount,
    required DateTime date,
    required String expenseAccountId,
    required String paymentAccountId,
    String? costCenterId,
  }) async {
    final dao = db.accountingDao;
    final branchId = await _getDefaultBranchId();

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: description,
      date: Value(date),
      referenceType: const Value('EXPENSE'),
      branchId: Value(branchId),
    );
    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: expenseAccountId,
        debit: Value(amount),
        credit: Value(Decimal.zero),
        costCenterId: Value(costCenterId),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: paymentAccountId,
        debit: Value(Decimal.zero),
        credit: Value(amount),
        costCenterId: Value(costCenterId),
        branchId: Value(branchId),
      ),
    ];
    await dao.createEntry(entry, lines);

    await _auditService.logCreate('EXPENSE', entryId, details: description);
  }

  Future<void> createRevaluationEntry(
    dynamic invoice,
    String reason, {
    String? debitAccountId,
    String? creditAccountId,
    Decimal? amount,
  }) async {
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();
    final branchId = await _getDefaultBranchId();

    Decimal revalAmount;
    String actualDebitAccountId;
    String actualCreditAccountId;

    if (amount != null && debitAccountId != null && creditAccountId != null) {
      revalAmount = amount;
      actualDebitAccountId = debitAccountId;
      actualCreditAccountId = creditAccountId;
    } else {
      final previousValue =
          Decimal.tryParse('${invoice.previousValue}') ?? Decimal.zero;
      final newValue = Decimal.tryParse('${invoice.newValue}') ?? Decimal.zero;
      revalAmount = (newValue - previousValue).abs();

      if (revalAmount <= Decimal.zero) {
        throw Exception('لا يوجد فرق في القيمة لإعادة التقييم.');
      }

      if (newValue > previousValue) {
        actualDebitAccountId =
            (await dao.getAccountByCode(AccountCodes.fixedAssets))?.id ??
                invoice.assetId;
        actualCreditAccountId =
            (await dao.getAccountByCode(AccountCodes.retainedEarnings))?.id ??
                'retained_earnings';
      } else {
        actualDebitAccountId =
            (await dao.getAccountByCode(AccountCodes.retainedEarnings))?.id ??
                'retained_earnings';
        actualCreditAccountId =
            (await dao.getAccountByCode(AccountCodes.fixedAssets))?.id ??
                invoice.assetId;
      }
    }

    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: 'إعادة تقييم: $reason (المرجع: ${invoice.id})',
      date: Value(DateTime.now()),
      referenceType: const Value('REVALUATION'),
      referenceId: Value(invoice.id),
      branchId: Value(branchId),
    );

    final lines = [
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: actualDebitAccountId,
        debit: Value(revalAmount),
        credit: Value(Decimal.zero),
        memo: Value('إعادة تقييم: $reason (مدين)'),
        branchId: Value(branchId),
      ),
      GLLinesCompanion.insert(
        entryId: entryId,
        accountId: actualCreditAccountId,
        debit: Value(Decimal.zero),
        credit: Value(revalAmount),
        memo: Value('إعادة تقييم: $reason (دائن)'),
        branchId: Value(branchId),
      ),
    ];

    await db.transaction(() async {
      await dao.createEntry(entry, lines);
      await _auditService.logCreate('GLEntry', entryId,
          details: 'Revaluation for invoice ${invoice.id}: $reason');
    });
  }

  Future<String> _getDefaultBranchId() async {
    return await _configService.getDefaultBranchId();
  }
}
