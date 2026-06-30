import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class BankReconciliationService {
  final AppDatabase db;

  BankReconciliationService(this.db);

  Future<List<UnmatchedTransaction>> getUnmatchedTransactions({
    required String accountId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final reconciledEntryIds = await _getReconciledEntryIds(accountId);

    final glLines = await (db.select(db.gLLines).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
          ..where(db.gLLines.accountId.equals(accountId))
          ..where(db.gLEntries.date.isBetweenValues(fromDate, toDate)))
        .get();

    final unmatched = <UnmatchedTransaction>[];
    for (final row in glLines) {
      final line = row.readTable(db.gLLines);
      final entry = row.readTable(db.gLEntries);
      if (reconciledEntryIds.contains(entry.id)) continue;

      unmatched.add(UnmatchedTransaction(
        glLineId: line.id,
        entryId: entry.id,
        date: entry.date,
        description: entry.description,
        amount: line.debit - line.credit,
        reference: entry.referenceId ?? '',
      ));
    }
    return unmatched;
  }

  Future<Set<String>> _getReconciledEntryIds(String accountId) async {
    final matched = await (db.select(db.reconciliations)
          ..where((r) => r.accountId.equals(accountId)))
        .get();
    return matched.map((r) => r.id).toSet();
  }

  Future<void> reconcileTransaction({
    required String accountId,
    required String glLineId,
    required String entryId,
    DateTime? date,
  }) async {
    final existing = await (db.select(db.reconciliations)
          ..where((r) => r.accountId.equals(accountId))
          ..where((r) => r.id.equals(entryId)))
        .getSingleOrNull();
    if (existing != null) return;

    await db.into(db.reconciliations).insert(
          ReconciliationsCompanion.insert(
            accountId: accountId,
            date: Value(date ?? DateTime.now()),
          ),
        );
  }

  Future<void> unreconcileTransaction({
    required String accountId,
    required String entryId,
  }) async {
    await (db.delete(db.reconciliations)
          ..where((r) => r.accountId.equals(accountId))
          ..where((r) => r.id.equals(entryId)))
        .go();
  }

  Future<int> autoReconcile({
    required String accountId,
    required List<BankStatementLine> bankLines,
    Decimal? tolerance,
  }) async {
    tolerance ??= Decimal.parse('0.01');
    final fromDate = DateTime(2000);
    final toDate = DateTime.now();
    final unmatched = await getUnmatchedTransactions(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
    );

    int matched = 0;
    final usedEntryIds = <String>{};

    for (final bankLine in bankLines) {
      for (final glTx in unmatched) {
        if (usedEntryIds.contains(glTx.entryId)) continue;
        final diff = (bankLine.amount - glTx.amount).abs();
        if (diff <= tolerance) {
          await reconcileTransaction(
            accountId: accountId,
            glLineId: glTx.glLineId,
            entryId: glTx.entryId,
            date: bankLine.date,
          );
          usedEntryIds.add(glTx.entryId);
          matched++;
          break;
        }
      }
    }
    return matched;
  }

  Future<ReconciliationSummary> getReconciliationSummary({
    required String accountId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final unmatched = await getUnmatchedTransactions(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
    );

    Decimal totalUnmatchedDebit = Decimal.zero;
    Decimal totalUnmatchedCredit = Decimal.zero;
    for (final tx in unmatched) {
      if (tx.amount > Decimal.zero) {
        totalUnmatchedDebit += tx.amount;
      } else {
        totalUnmatchedCredit += tx.amount.abs();
      }
    }

    return ReconciliationSummary(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
      unmatchedCount: unmatched.length,
      totalUnmatchedDebit: totalUnmatchedDebit,
      totalUnmatchedCredit: totalUnmatchedCredit,
      unmatchedTransactions: unmatched,
    );
  }
}

class BankStatementLine {
  final DateTime date;
  final String description;
  final Decimal amount;
  final String? reference;

  BankStatementLine({
    required this.date,
    required this.description,
    required this.amount,
    this.reference,
  });
}

class ReconciliationSummary {
  final String accountId;
  final DateTime fromDate;
  final DateTime toDate;
  final int unmatchedCount;
  final Decimal totalUnmatchedDebit;
  final Decimal totalUnmatchedCredit;
  final List<UnmatchedTransaction> unmatchedTransactions;

  ReconciliationSummary({
    required this.accountId,
    required this.fromDate,
    required this.toDate,
    required this.unmatchedCount,
    required this.totalUnmatchedDebit,
    required this.totalUnmatchedCredit,
    required this.unmatchedTransactions,
  });
}

class UnmatchedTransaction {
  final String glLineId;
  final String entryId;
  final DateTime date;
  final String description;
  final Decimal amount;
  final String reference;

  UnmatchedTransaction({
    required this.glLineId,
    required this.entryId,
    required this.date,
    required this.description,
    required this.amount,
    required this.reference,
  });
}
