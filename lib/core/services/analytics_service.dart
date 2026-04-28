import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AnalyticsService {
  final AppDatabase db;
  AnalyticsService(this.db);

  /// يحسب معدل دوران المخزون: (تكلفة البضاعة المباعة / متوسط المخزون)
  Future<double> getInventoryTurnover({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. Get COGS from GL entries
    final cogsAccount = await (db.select(db.gLAccounts)..where((a) => a.code.equals('COGS'))).getSingleOrNull();
    if (cogsAccount == null) return 0.0;

    final cogsQuery = (db.select(db.gLLines).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])..where(
      db.gLLines.accountId.equals(cogsAccount.id) &
      db.gLEntries.date.isBetween(Variable(startDate), Variable(endDate)),
    ));
    
    final cogsLines = await cogsQuery.get();
    double totalCogs = cogsLines.fold(0.0, (sum, line) => sum + (line.read(db.gLLines.debit) ?? 0.0));

    // 2. Get Average Inventory (Beginning + Ending) / 2
    double beginningInventory = await db.accountingDao.getAccountBalanceAsOfDate('inventory', startDate.subtract(const Duration(days: 1)));
    double endingInventory = await db.accountingDao.getAccountBalanceAsOfDate('inventory', endDate);
    
    double averageInventory = (beginningInventory + endingInventory) / 2;

    if (averageInventory == 0) return 0.0;
    return totalCogs / averageInventory;
  }

  /// يتوقع مبيعات الأسبوع القادم بناءً على مبيعات آخر 4 أسابيع
  Future<double> predictNextWeekSales() async {
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 28));

    final sales = await (db.select(db.sales)..where((t) => t.createdAt.isBiggerOrEqual(Variable(oneMonthAgo)))).get();
    
    if (sales.isEmpty) return 0.0;
    
    double totalMonthSales = sales.fold(0.0, (sum, s) => sum + s.total);
    return totalMonthSales / 4; // المتوسط الأسبوعي
  }

  /// يحسب صافي الربح لفترة
  Future<double> getNetProfit({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final incomeStatement = await db.accountingDao.getIncomeStatement(
      startDate: startDate,
      endDate: endDate,
    );
    return incomeStatement.netIncome;
  }
}
