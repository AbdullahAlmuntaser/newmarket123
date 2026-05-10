import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class UnifiedStatementService {
  final AppDatabase db;

  UnifiedStatementService(this.db);

  Future<List<UnifiedStatementEntry>> getUnifiedStatement({
    required String accountId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await (db.select(db.accountTransactions)
          ..where((t) => t.accountId.equals(accountId))
          ..where((t) => t.date.isBetweenValues(startDate, endDate))
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();

    double runningBalance = 0.0;
    
    // Get opening balance
    final openingBalanceTrans = await (db.select(db.accountTransactions)
          ..where((t) => t.accountId.equals(accountId))
          ..where((t) => t.date.isSmallerThanValue(startDate))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
    
    runningBalance = openingBalanceTrans?.runningBalance ?? 0.0;

    List<UnifiedStatementEntry> entries = [];
    
    // Add opening balance entry
    entries.add(UnifiedStatementEntry(
      date: startDate,
      description: 'رصيد افتتاحى / Opening Balance',
      debit: 0,
      credit: 0,
      balance: runningBalance,
      referenceId: '',
      type: 'OPENING',
    ));

    for (var t in transactions) {
      entries.add(UnifiedStatementEntry(
        date: t.date,
        description: await _getTransactionDescription(t),
        debit: t.debit,
        credit: t.credit,
        balance: t.runningBalance,
        referenceId: t.referenceId ?? '',
        type: t.type,
      ));
    }

    return entries;
  }

  Future<String> _getTransactionDescription(AccountTransaction t) async {
    if (t.type == 'INVOICE') {
      return 'فاتورة رقم: ${t.referenceId}';
    } else if (t.type == 'PAYMENT') {
      return 'سند صرف رقم: ${t.referenceId}';
    } else if (t.type == 'RECEIPT') {
      return 'سند قبض رقم: ${t.referenceId}';
    } else if (t.type == 'RETURN') {
      return 'مردودات رقم: ${t.referenceId}';
    } else if (t.type == 'TRANSFER') {
      return 'تحويل مالي رقم: ${t.referenceId}';
    } else if (t.type == 'HR_ADVANCE') {
      return 'سلفة موظف رقم: ${t.referenceId}';
    }
    return t.type;
  }
}

class UnifiedStatementEntry {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String referenceId;
  final String type;

  UnifiedStatementEntry({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.referenceId,
    required this.type,
  });
}
