import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class AccountingPeriodService {
  final AppDatabase db;

  AccountingPeriodService(this.db);

  /// إنشاء فترات محاسبية تلقائية لسنة معينة
  Future<int> bulkCreatePeriods({
    required int year,
    required String type, // monthly, quarterly, yearly
  }) async {
    final periods = <AccountingPeriodsCompanion>[];
    final uuid = const Uuid();

    if (type == 'yearly') {
      // فترة سنوية واحدة
      periods.add(AccountingPeriodsCompanion.insert(
        id: Value(uuid.v4()),
        name: 'السنة $year',
        startDate: DateTime(year, 1, 1),
        endDate: DateTime(year, 12, 31),
        status: const Value('OPEN'),
        syncStatus: const Value(1),
      ));
    } else if (type == 'quarterly') {
      // 4 فترات ربع سنوية
      const quarters = ['الربع الأول', 'الربع الثاني', 'الربع الثالث', 'الربع الرابع'];
      for (int i = 0; i < 4; i++) {
        final startMonth = (i * 3) + 1;
        final endMonth = startMonth + 2;
        periods.add(AccountingPeriodsCompanion.insert(
          id: Value(uuid.v4()),
          name: '${quarters[i]} $year',
          startDate: DateTime(year, startMonth, 1),
          endDate: DateTime(year, endMonth, DateTime(year, endMonth + 1, 0).day),
          status: const Value('OPEN'),
          syncStatus: const Value(1),
        ));
      }
    } else if (type == 'monthly') {
      // 12 فترة شهرية
      const months = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      for (int i = 1; i <= 12; i++) {
        final daysInMonth = DateTime(year, i + 1, 0).day;
        periods.add(AccountingPeriodsCompanion.insert(
          id: Value(uuid.v4()),
          name: '${months[i]} $year',
          startDate: DateTime(year, i, 1),
          endDate: DateTime(year, i, daysInMonth),
          status: const Value('OPEN'),
          syncStatus: const Value(1),
        ));
      }
    }

    // إدخال الفترات في قاعدة البيانات
    int count = 0;
    await db.transaction(() async {
      for (final period in periods) {
        await db.into(db.accountingPeriods).insert(period);
        count++;
      }
    });

    return count;
  }

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
      await (db.update(db.accountingPeriods)
            ..where((p) => p.id.equals(periodId)))
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
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return months[month];
  }

  /// Checks if a transaction date is allowed (must not be in a closed period)
  Future<bool> isDateAllowed(DateTime date) async {
    final closedPeriods = await (db.select(db.accountingPeriods)
          ..where((p) =>
              p.isClosed.equals(true) &
              p.startDate.isSmallerOrEqual(Variable(date)) &
              p.endDate.isBiggerOrEqual(Variable(date))))
        .get();

    return closedPeriods.isEmpty;
  }
}
