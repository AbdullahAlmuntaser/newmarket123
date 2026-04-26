import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

enum TransactionType {
  sale,
  purchase,
  returnSale,
  returnPurchase,
  paymentIn,
  paymentOut,
}

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
  final AppDatabase db;

  PostingEngine(this.db);

  Future<void> postEntry({
    required List<PostingLine> entries,
    required String reference,
    required DateTime date,
  }) async {
    await _checkPeriodOpen();

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
    final profile =
        await (db.select(db.postingProfiles)
              ..where((p) => p.operationType.equals(type.name))
              ..where((p) => p.isActive.equals(true)))
            .get();

    if (profile.isEmpty) throw Exception('No posting profile found for $type');

    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ?? 'Transaction: $type',
      date: Value(DateTime.now()),
      referenceType: Value(type.name),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
    );

    List<GLLinesCompanion> lines = [];
    for (var p in profile) {
      if (p.accountId == null) continue;
      lines.add(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: p.accountId!,
          debit: Value(p.side == 'DEBIT' ? (context['amount'] ?? 0.0) : 0.0),
          credit: Value(p.side == 'CREDIT' ? (context['amount'] ?? 0.0) : 0.0),
        ),
      );
    }
    await db.accountingDao.createEntry(entry, lines);
  }

  Future<void> _checkPeriodOpen() async {
    final now = DateTime.now();
    final period =
        await (db.select(db.accountingPeriods)
              ..where((p) => p.isClosed.equals(false))
              ..where((p) => p.startDate.isSmallerOrEqualValue(now))
              ..where((p) => p.endDate.isBiggerOrEqualValue(now)))
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
