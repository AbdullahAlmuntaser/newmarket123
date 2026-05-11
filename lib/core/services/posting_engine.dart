import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';

class PostingLine {
  final String account;
  final double debit;
  final double credit;
  PostingLine({
    required this.account,
    required this.debit,
    required this.credit,
  });
}

class PostingEngine {
  static const double balanceTolerance = 0.001;

  final AppDatabase db;
  final InventoryCostingService? costingService;

  PostingEngine(this.db, {this.costingService});

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

    var totalDebit = 0.0;
    var totalCredit = 0.0;

    for (final entry in entries) {
      if (entry.account.trim().isEmpty) {
        throw Exception('الحساب المحاسبي غير محدد.');
      }
      if (!entry.debit.isFinite || !entry.credit.isFinite) {
        throw Exception('مبلغ القيد المحاسبي غير صالح.');
      }
      if (entry.debit < 0 || entry.credit < 0) {
        throw Exception('المبلغ يجب أن يكون أكبر من أو يساوي الصفر.');
      }
      if (entry.debit > 0 && entry.credit > 0) {
        throw Exception('لا يمكن أن يكون السطر مديناً ودائناً في نفس الوقت.');
      }
      if (entry.debit == 0 && entry.credit == 0) {
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

  Future<double> getTotalByAccount(
    String accountId,
    DateTime from,
    DateTime to,
  ) async {
    final query = db.select(db.gLLines)
      ..where((l) => l.accountId.equals(accountId));

    final results = await query.get();
    double total = 0.0;
    for (var line in results) {
      total += (line.debit - line.credit);
    }
    return total;
  }

  Future<double> getBalanceForAccount(String accountId) async {
    final query = db.select(db.gLLines)
      ..where((l) => l.accountId.equals(accountId));
    final results = await query.get();
    double total = 0.0;
    for (var line in results) {
      total += (line.debit - line.credit);
    }
    return total;
  }

  Future<void> post({
    required TransactionType type,
    required String referenceId,
    required Map<String, dynamic> context,
  }) async {
    await _checkPeriodOpen();

    developer.log('Posting transaction: $type, Reference: $referenceId',
        name: 'PostingEngine');

    final profile = await (db.select(db.postingProfiles)
          ..where((p) => p.operationType.equals(type.name.toUpperCase()))
          ..where((p) => p.isActive.equals(true)))
        .get();

    if (profile.isEmpty) {
      developer.log('No posting profile found for: ${type.name.toUpperCase()}',
          name: 'PostingEngine', level: 1000);
      throw Exception('No posting profile found for: ${type.name}');
    }

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ?? 'Transaction: $type',
      date: Value(DateTime.now()),
      referenceType: Value(type.name),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
    );

    final postingLines = <PostingLine>[];
    for (final profileLine in profile) {
      final accountId = profileLine.accountId;
      if (accountId == null || accountId.trim().isEmpty) continue;

      final amount = _resolveProfileAmount(type, profileLine, context);
      if (amount <= balanceTolerance) continue;

      switch (profileLine.side.toUpperCase()) {
        case 'DEBIT':
          postingLines.add(
            PostingLine(account: accountId, debit: amount, credit: 0.0),
          );
          break;
        case 'CREDIT':
          postingLines.add(
            PostingLine(account: accountId, debit: 0.0, credit: amount),
          );
          break;
        default:
          throw Exception('Invalid posting side: ${profileLine.side}');
      }
    }

    validatePostingLines(postingLines);

    final lines = postingLines
        .map(
          (line) => GLLinesCompanion.insert(
            entryId: entryId,
            accountId: line.account,
            debit: Value(line.debit),
            credit: Value(line.credit),
          ),
        )
        .toList();

    developer.log(
        'Successfully found profile and created lines for ${type.name}',
        name: 'PostingEngine');
    await db.accountingDao.createEntry(entry, lines);
  }

  double _resolveProfileAmount(
    TransactionType type,
    PostingProfile profileLine,
    Map<String, dynamic> context,
  ) {
    final accountType = profileLine.accountType.toUpperCase();

    if (type == TransactionType.purchase &&
        accountType == 'CASH' &&
        context['paymentMethod'] != 'cash') {
      return 0.0;
    }
    if (type == TransactionType.purchase &&
        accountType == 'PAYABLE' &&
        context['paymentMethod'] == 'cash') {
      return 0.0;
    }

    if (type == TransactionType.sale &&
        (accountType == 'COGS' || accountType == 'INVENTORY')) {
      return _readAmount(context['cogs']);
    }

    return _readAmount(context['amount']);
  }

  double _readAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
    final query = db.select(db.gLLines)
      ..where((l) => l.accountId.equals(accountId));

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
