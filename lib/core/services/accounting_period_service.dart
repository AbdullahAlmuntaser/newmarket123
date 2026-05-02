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

  /// Ensures there's an open accounting period for the current month
  Future<void> ensureOpenPeriod() async {
    final now = DateTime.now();
    final period = await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..where((p) => p.startDate.isSmallerOrEqual(Variable(now)))
          ..where((p) => p.endDate.isBiggerOrEqual(Variable(now))))
        .getSingleOrNull();

    if (period == null) {
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      await db.into(db.accountingPeriods).insert(
        AccountingPeriodsCompanion.insert(
          name: '${_getMonthName(now.month)} ${now.year}',
          startDate: startOfMonth,
          endDate: endOfMonth,
          status: const Value('OPEN'),
        ),
      );
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month];
  }

  /// Checks if a transaction date is allowed (must not be in a closed period)
  Future<bool> isDateAllowed(DateTime date) async {
    final closedPeriods = await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(true) & p.startDate.isSmallerOrEqual(Variable(date)) & p.endDate.isBiggerOrEqual(Variable(date))))
        .get();
        
    return closedPeriods.isEmpty;
  }
}
