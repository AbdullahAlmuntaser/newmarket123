import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AccountingPeriodService {
  final AppDatabase db;

  AccountingPeriodService(this.db);

  /// Closes the current accounting period and prevents further transactions in it.
  Future<void> closePeriod(String periodId, String closedBy) async {
    final period = await (db.select(db.accountingPeriods)
          ..where((p) => p.id.equals(periodId)))
        .getSingle();

    if (period.isClosed) {
      throw Exception('هذه الفترة مغلقة بالفعل.');
    }

    await db.transaction(() async {
      // 1. تحديث حالة الفترة
      await (db.update(db.accountingPeriods)..where((p) => p.id.equals(periodId)))
          .write(AccountingPeriodsCompanion(
        isClosed: const Value(true),
        closedAt: Value(DateTime.now()),
        closedBy: Value(closedBy),
        status: const Value('CLOSED'),
      ));
    });
  }

  /// Checks if a transaction date is allowed (must not be in a closed period)
  Future<bool> isDateAllowed(DateTime date) async {
    final closedPeriods = await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(true) & p.startDate.isSmallerOrEqualValue(date) & p.endDate.isBiggerOrEqualValue(date)))
        .get();
        
    return closedPeriods.isEmpty;
  }
}
