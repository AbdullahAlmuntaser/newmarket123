import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'transfers_dao.g.dart';

@DriftAccessor(tables: [FinancialTransfers, GLAccounts, Checks])
class TransfersDao extends DatabaseAccessor<AppDatabase> with _$TransfersDaoMixin {
  TransfersDao(super.db);

  Stream<List<FinancialTransfer>> watchAllTransfers() =>
      (select(financialTransfers)
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .watch();

  Future<int> insertTransfer(FinancialTransfersCompanion companion) =>
      into(financialTransfers).insert(companion);

  Future<FinancialTransfer?> getTransferById(String id) =>
      (select(financialTransfers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> updateTransfer(FinancialTransfer transfer) =>
      update(financialTransfers).replace(transfer);
}
