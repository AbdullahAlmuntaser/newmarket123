import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:uuid/uuid.dart';

class CashManagementService {
  final AppDatabase db;
  final EventBusService eventBus;

  CashManagementService(this.db, this.eventBus);

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
      
      // 1. Cashbox Transaction
      await db.cashboxDao.insertTransaction(
        CashboxTransactionsCompanion.insert(
          id: Value(id),
          amount: amount,
          type: 'IN',
          category: category,
          note: Value(note),
          userId: userId ?? '',
          referenceId: Value(referenceId ?? id),
        ),
      );

      // 2. Fire Event for Accounting
      eventBus.fire(CashTransactionEvent(
        amount: amount,
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
      
      // 1. Cashbox Transaction
      await db.cashboxDao.insertTransaction(
        CashboxTransactionsCompanion.insert(
          id: Value(id),
          amount: amount,
          type: 'OUT',
          category: category,
          note: Value(note),
          userId: userId ?? '',
          referenceId: Value(referenceId ?? id),
        ),
      );

      // 2. Fire Event for Accounting
      eventBus.fire(CashTransactionEvent(
        amount: amount,
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
