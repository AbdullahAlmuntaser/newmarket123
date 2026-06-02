import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:uuid/uuid.dart';

class CashManagementService {
  final AppDatabase db;
  final AccountingService accountingService;

  CashManagementService(this.db, this.accountingService);

  Future<void> createCashReceipt({
    required double amount,
    required String category,
    required String accountId,
    String? note,
    String? userId,
    String? referenceId,
  }) async {
    await db.transaction(() async {
      final id = const Uuid().v4();
      final decimalAmount = Decimal.parse(amount.toString());
      
      // 1. Cashbox Transaction
      await db.cashboxDao.insertTransaction(
        CashboxTransactionsCompanion.insert(
          id: Value(id),
          amount: decimalAmount.toDouble(),
          type: 'IN',
          category: category,
          note: Value(note),
          userId: userId ?? '',
          referenceId: Value(referenceId ?? id),
        ),
      );

      // 2. Post accounting atomically with the cashbox movement.
      await accountingService.postCashTransactionEvent(CashTransactionEvent(
        amount: decimalAmount,
        type: 'IN',
        category: category,
        accountId: accountId,
        referenceId: referenceId ?? id,
        note: note,
        userId: userId,
      ));
    });
  }

  Future<void> createCashPayment({
    required double amount,
    required String category,
    required String accountId,
    String? note,
    String? userId,
    String? referenceId,
  }) async {
    await db.transaction(() async {
      final id = const Uuid().v4();
      final decimalAmount = Decimal.parse(amount.toString());
      
      // 1. Cashbox Transaction
      await db.cashboxDao.insertTransaction(
        CashboxTransactionsCompanion.insert(
          id: Value(id),
          amount: decimalAmount.toDouble(),
          type: 'OUT',
          category: category,
          note: Value(note),
          userId: userId ?? '',
          referenceId: Value(referenceId ?? id),
        ),
      );

      // 2. Post accounting atomically with the cashbox movement.
      await accountingService.postCashTransactionEvent(CashTransactionEvent(
        amount: decimalAmount,
        type: 'OUT',
        category: category,
        accountId: accountId,
        referenceId: referenceId ?? id,
        note: note,
        userId: userId,
      ));
    });
  }
}
