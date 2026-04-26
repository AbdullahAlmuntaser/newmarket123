import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ReportingService {
  final AppDatabase db;

  ReportingService(this.db);

  /// Generates a simple P&L for a period
  Future<Map<String, double>> getProfitAndLoss(DateTime from, DateTime to) async {
    final revenue = await _getAccountTotalByType('REVENUE', from, to);
    final cogs = await _getAccountTotalByType('EXPENSE', from, to); // Simplified

    return {
      'revenue': revenue,
      'cogs': cogs,
      'netProfit': revenue - cogs,
    };
  }

  Future<double> _getAccountTotalByType(String type, DateTime from, DateTime to) async {
    final query = db.select(db.gLLines).join([
      innerJoin(db.gLAccounts, db.gLAccounts.id.equalsExp(db.gLLines.accountId)),
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])..where(db.gLAccounts.type.equals(type))
      ..where(db.gLEntries.date.isBiggerOrEqualValue(from))
      ..where(db.gLEntries.date.isSmallerOrEqualValue(to));

    final results = await query.get();
    double total = 0.0;
    for (var row in results) {
       final line = row.readTable(db.gLLines);
       total += (line.debit - line.credit);
    }
    return total;
  }
}
