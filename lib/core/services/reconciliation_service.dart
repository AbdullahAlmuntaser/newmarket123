import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class ReconciliationSummary {
  final Decimal openingBalance;
  final Decimal statementClosingBalance;
  final Decimal systemClosingBalance;
  final Decimal matchedDebits;
  final Decimal matchedCredits;
  final Decimal unmatchedDebits;
  final Decimal unmatchedCredits;
  final Decimal difference;

  ReconciliationSummary({
    required this.openingBalance,
    required this.statementClosingBalance,
    required this.systemClosingBalance,
    required this.matchedDebits,
    required this.matchedCredits,
    required this.unmatchedDebits,
    required this.unmatchedCredits,
    required this.difference,
  });
}

class ReconciliationService {
  final AppDatabase db;

  ReconciliationService(this.db);

  Future<String> startReconciliation({
    required String accountId,
    required Decimal bookBalance,
    required Decimal actualBalance,
    String? note,
  }) async {
    final id = const Uuid().v4();
    await db.into(db.reconciliations).insert(
          ReconciliationsCompanion.insert(
            id: Value(id),
            accountId: accountId,
            bookBalance: Value(bookBalance),
            actualBalance: Value(actualBalance),
            note: Value(note),
          ),
        );
    return id;
  }

  Future<List<AccountTransaction>> getUnreconciledTransactions(
    String accountId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final query = db.select(db.accountTransactions)
      ..where((t) => t.accountId.equals(accountId))
      ..where((t) => t.reconciled.equals(false));
    if (from != null) {
      query.where((t) => t.date.isBiggerOrEqual(Variable(from)));
    }
    if (to != null) {
      query.where((t) => t.date.isSmallerOrEqual(Variable(to)));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.date)]);
    return query.get();
  }

  Future<void> matchTransaction({
    required String transactionId,
    required Decimal statementAmount,
    required DateTime statementDate,
    String? reference,
  }) async {
    await db.transaction(() async {
      await (db.update(db.accountTransactions)
            ..where((t) => t.id.equals(transactionId)))
          .write(const AccountTransactionsCompanion(reconciled: Value(true)));
    });
  }

  Future<void> unmatchTransaction(String transactionId) async {
    await (db.update(db.accountTransactions)
          ..where((t) => t.id.equals(transactionId)))
        .write(const AccountTransactionsCompanion(reconciled: Value(false)));
  }

  Future<ReconciliationSummary> getSummary(String reconciliationId) async {
    final reconciliation = await (db.select(db.reconciliations)
          ..where((r) => r.id.equals(reconciliationId)))
        .getSingle();

    final matched = await (db.select(db.accountTransactions)
          ..where((t) => t.reconciled.equals(true))
          ..where((t) => t.accountId.equals(reconciliation.accountId)))
        .get();

    Decimal matchedDebits = Decimal.zero;
    Decimal matchedCredits = Decimal.zero;
    for (final tx in matched) {
      matchedDebits += tx.debit;
      matchedCredits += tx.credit;
    }

    final unmatched = await getUnreconciledTransactions(
      reconciliation.accountId,
    );
    Decimal unmatchedDebits = Decimal.zero;
    Decimal unmatchedCredits = Decimal.zero;
    for (final tx in unmatched) {
      unmatchedDebits += tx.debit;
      unmatchedCredits += tx.credit;
    }

    final dao = db.accountingDao;
    final systemBalance = await dao.getAccountBalanceAsOfDate(
        reconciliation.accountId, DateTime.now());
    final difference = systemBalance - reconciliation.actualBalance;

    return ReconciliationSummary(
      openingBalance: reconciliation.bookBalance,
      statementClosingBalance: reconciliation.actualBalance,
      systemClosingBalance: systemBalance,
      matchedDebits: matchedDebits,
      matchedCredits: matchedCredits,
      unmatchedDebits: unmatchedDebits,
      unmatchedCredits: unmatchedCredits,
      difference: difference,
    );
  }

  Future<List<Reconciliation>> getReconciliationHistory(
      String accountId) async {
    return (db.select(db.reconciliations)
          ..where((r) => r.accountId.equals(accountId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.date, mode: OrderingMode.desc)
          ]))
        .get();
  }
}
