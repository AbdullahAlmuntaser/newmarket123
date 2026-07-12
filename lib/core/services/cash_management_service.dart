import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';

class CashManagementService {
  final AppDatabase db;
  final PostingEngine postingEngine;

  CashManagementService(this.db, this.postingEngine);

  Future<void> createCashReceipt({
    required Decimal amount,
    required String category,
    required String accountId,
    String? note,
    String? userId,
    String? referenceId,
  }) async {
    await db.transaction(() async {
      final id = const Uuid().v4();

      await db.cashboxDao.insertTransaction(
        CashboxTransactionsCompanion.insert(
          id: Value(id),
          amount: Value(amount),
          type: 'IN',
          category: category,
          note: Value(note),
          userId: userId ?? '',
          referenceId: Value(referenceId ?? id),
        ),
      );

      await postingEngine.post(
        type: TransactionType.cashReceipt,
        referenceId: referenceId ?? id,
        context: {
          'amount': amount,
          'accountId': accountId,
          'category': category,
          'note': note,
          'description': 'سند قبض: $category${note != null ? " - $note" : ""}',
          'cashDirection': 'IN',
        },
      );
    });
  }

  Future<void> createCashPayment({
    required Decimal amount,
    required String category,
    required String accountId,
    String? note,
    String? userId,
    String? referenceId,
  }) async {
    await db.transaction(() async {
      final id = const Uuid().v4();

      await db.cashboxDao.insertTransaction(
        CashboxTransactionsCompanion.insert(
          id: Value(id),
          amount: Value(amount),
          type: 'OUT',
          category: category,
          note: Value(note),
          userId: userId ?? '',
          referenceId: Value(referenceId ?? id),
        ),
      );

      await postingEngine.post(
        type: TransactionType.cashPayment,
        referenceId: referenceId ?? id,
        context: {
          'amount': amount,
          'accountId': accountId,
          'category': category,
          'note': note,
          'description': 'سند صرف: $category${note != null ? " - $note" : ""}',
          'cashDirection': 'OUT',
        },
      );
    });
  }
}
