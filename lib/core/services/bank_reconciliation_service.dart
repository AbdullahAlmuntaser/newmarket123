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
      unmatched.add(UnmatchedTransaction(
        glLineId: line.id,
        date: entry.date,
        description: entry.description,
        amount: line.debit - line.credit,
        reference: entry.referenceId ?? '',
      ));
    }
    return unmatched;
  }

  Future<void> reconcileTransaction({
    required String accountId,
    required String glLineId,
    DateTime? date,
  }) async {
    await db.into(db.reconciliations).insert(
          ReconciliationsCompanion.insert(
            accountId: accountId,
            date: Value(date ?? DateTime.now()),
          ),
        );
  }

  Future<int> autoReconcile({
    required String accountId,
    Decimal? tolerance,
  }) async {
    tolerance ??= Decimal.zero;
    final fromDate = DateTime(2000);
    final toDate = DateTime.now();
    final unmatched = await getUnmatchedTransactions(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
    );

    int matched = 0;
    for (final tx in unmatched) {
      if (tx.amount.abs() <= tolerance) {
        await reconcileTransaction(
          accountId: accountId,
          glLineId: tx.glLineId,
          date: tx.date,
        );
        matched++;
      }
    }
    return matched;
  }
}

class UnmatchedTransaction {
  final String glLineId;
  final DateTime date;
  final String description;
  final Decimal amount;
  final String reference;

  UnmatchedTransaction({
    required this.glLineId,
    required this.date,
    required this.description,
    required this.amount,
    required this.reference,
  });
}
