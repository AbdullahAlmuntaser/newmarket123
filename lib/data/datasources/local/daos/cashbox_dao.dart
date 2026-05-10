import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'cashbox_dao.g.dart';

@DriftAccessor(tables: [CashboxTransactions, GLAccounts])
class CashboxDao extends DatabaseAccessor<AppDatabase> with _$CashboxDaoMixin {
  CashboxDao(super.db);

  Stream<List<CashboxTransaction>> watchAllTransactions() =>
      (select(cashboxTransactions)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .watch();

  Future<int> insertTransaction(CashboxTransactionsCompanion companion) =>
      into(cashboxTransactions).insert(companion);

  Future<List<CashboxTransaction>> getTransactionsByReference(String referenceId) =>
      (select(cashboxTransactions)..where((t) => t.referenceId.equals(referenceId))).get();

  Future<double> getCashboxBalance({String? userId}) async {
    final query = selectOnly(cashboxTransactions)..addColumns([cashboxTransactions.amount, cashboxTransactions.type]);
    if (userId != null) {
      query.where(cashboxTransactions.userId.equals(userId));
    }
    
    final rows = await query.get();
    double balance = 0;
    for (final row in rows) {
      final amount = row.read(cashboxTransactions.amount) ?? 0.0;
      final type = row.read(cashboxTransactions.type);
      if (type == 'IN') {
        balance += amount;
      } else if (type == 'OUT') {
        balance -= amount;
      }
    }
    return balance;
  }
}
