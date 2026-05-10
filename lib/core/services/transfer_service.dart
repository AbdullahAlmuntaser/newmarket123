import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class TransferService {
  final AppDatabase db;

  TransferService(this.db);

  Future<void> createTransfer({
    required String senderAccountId,
    required String receiverAccountId,
    required double amount,
    double commission = 0.0,
    String? company,
    required String transferType, // CASH, BANK, CHECK
    String? checkId,
    String? note,
    String? branchId,
  }) async {
    await db.transaction(() async {
      final id = const Uuid().v4();
      final entryId = const Uuid().v4();

      // 1. Create GL Entry
      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description: 'تحويل مالي: من حـ/ ${await _getAccountName(senderAccountId)} إلى حـ/ ${await _getAccountName(receiverAccountId)} ${note ?? ""}',
        date: Value(DateTime.now()),
        referenceType: const Value('TRANSFER'),
        referenceId: Value(id),
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
      );

      final lines = [
        // Debit Receiver
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: receiverAccountId,
          debit: Value(amount),
          credit: const Value(0.0),
        ),
        // Credit Sender
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: senderAccountId,
          debit: const Value(0.0),
          credit: Value(amount + commission),
        ),
        // Debit Commission Expense (if any)
        if (commission > 0)
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: (await db.accountingDao.getAccountByCode('6010'))!.id, // Commission Expense
            debit: Value(commission),
            credit: const Value(0.0),
          ),
      ];

      await db.accountingDao.createEntry(entry, lines);

      // 2. Insert Transfer Record
      await db.transfersDao.insertTransfer(
        FinancialTransfersCompanion.insert(
          id: Value(id),
          senderAccountId: senderAccountId,
          receiverAccountId: receiverAccountId,
          amount: amount,
          commission: Value(commission),
          company: Value(company),
          transferType: transferType,
          checkId: Value(checkId),
          date: Value(DateTime.now()),
          note: Value(note),
          status: const Value('POSTED'),
        ),
      );
    });
  }

  Future<String> _getAccountName(String id) async {
    final acc = await db.accountingDao.getAccountById(id);
    return acc?.name ?? 'حساب غير معروف';
  }
}
