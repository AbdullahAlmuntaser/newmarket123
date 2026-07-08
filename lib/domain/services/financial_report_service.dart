import 'package:sqflite/sqflite.dart';

class FinancialReportService {
  final Database database;

  FinancialReportService({required this.database});

  /// Generate Balance Sheet
  Future<Map<String, dynamic>> generateBalanceSheet({
    required DateTime asOfDate,
  }) async {
    final dateString = asOfDate.toIso8601String().split('T').first;

    // Get Assets
    final assets = await _getAccountBalancesByType('ASSET', beforeDate: dateString);
    
    // Get Liabilities
    final liabilities = await _getAccountBalancesByType('LIABILITY', beforeDate: dateString);
    
    // Get Equity
    final equity = await _getAccountBalancesByType('EQUITY', beforeDate: dateString);
    
    // Calculate Retained Earnings (Revenue - Expenses)
    final revenue = await _getAccountBalancesByType('REVENUE', beforeDate: dateString);
    final expenses = await _getAccountBalancesByType('EXPENSE', beforeDate: dateString);
    
    double totalRevenue = revenue.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble());
    double totalExpenses = expenses.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble());
    final retainedEarnings = totalRevenue - totalExpenses;

    return {
      'as_of_date': dateString,
      'assets': assets,
      'liabilities': liabilities,
      'equity': equity,
      'retained_earnings': retainedEarnings,
      'total_assets': assets.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble()),
      'total_liabilities': liabilities.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble()),
      'total_equity': equity.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble()) + retainedEarnings,
    };
  }

  /// Generate Income Statement
  Future<Map<String, dynamic>> generateIncomeStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startString = startDate.toIso8601String().split('T').first;
    final endString = endDate.toIso8601String().split('T').first;

    // Get Revenue
    final revenue = await _getAccountBalancesByType('REVENUE', 
      startDate: startString, endDate: endString);
    
    // Get Expenses
    final expenses = await _getAccountBalancesByType('EXPENSE', 
      startDate: startString, endDate: endString);
    
    final totalRevenue = revenue.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble());
    final totalExpenses = expenses.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble());
    final netProfit = totalRevenue - totalExpenses;

    return {
      'start_date': startString,
      'end_date': endString,
      'revenue': revenue,
      'expenses': expenses,
      'total_revenue': totalRevenue,
      'total_expenses': totalExpenses,
      'net_profit': netProfit,
    };
  }

  /// Generate Cash Flow Statement
  Future<Map<String, dynamic>> generateCashFlowStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startString = startDate.toIso8601String().split('T').first;
    final endString = endDate.toIso8601String().split('T').first;

    // Get operating activities
    final operatingActivities = await database.query(
      'cash_flow_entries',
      where: 'transaction_type = ? AND entry_date BETWEEN ? AND ?',
      whereArgs: ['operating', startString, endString],
    );

    // Get investing activities
    final investingActivities = await database.query(
      'cash_flow_entries',
      where: 'transaction_type = ? AND entry_date BETWEEN ? AND ?',
      whereArgs: ['investing', startString, endString],
    );

    // Get financing activities
    final financingActivities = await database.query(
      'cash_flow_entries',
      where: 'transaction_type = ? AND entry_date BETWEEN ? AND ?',
      whereArgs: ['financing', startString, endString],
    );

    final cashInOperating = operatingActivities
      .where((e) => e['activity_type'] == 'cash_in')
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());
    
    final cashOutOperating = operatingActivities
      .where((e) => e['activity_type'] == 'cash_out')
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

    final cashInInvesting = investingActivities
      .where((e) => e['activity_type'] == 'cash_in')
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());
    
    final cashOutInvesting = investingActivities
      .where((e) => e['activity_type'] == 'cash_out')
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

    final cashInFinancing = financingActivities
      .where((e) => e['activity_type'] == 'cash_in')
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());
    
    final cashOutFinancing = financingActivities
      .where((e) => e['activity_type'] == 'cash_out')
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

    final netCashFromOperating = cashInOperating - cashOutOperating;
    final netCashFromInvesting = cashInInvesting - cashOutInvesting;
    final netCashFromFinancing = cashInFinancing - cashOutFinancing;
    final netChangeInCash = netCashFromOperating + netCashFromInvesting + netCashFromFinancing;

    return {
      'start_date': startString,
      'end_date': endString,
      'operating_activities': {
        'cash_in': cashInOperating,
        'cash_out': cashOutOperating,
        'net': netCashFromOperating,
        'entries': operatingActivities,
      },
      'investing_activities': {
        'cash_in': cashInInvesting,
        'cash_out': cashOutInvesting,
        'net': netCashFromInvesting,
        'entries': investingActivities,
      },
      'financing_activities': {
        'cash_in': cashInFinancing,
        'cash_out': cashOutFinancing,
        'net': netCashFromFinancing,
        'entries': financingActivities,
      },
      'net_change_in_cash': netChangeInCash,
    };
  }

  /// Generate Trial Balance
  Future<List<Map<String, dynamic>>> generateTrialBalance({
    required DateTime asOfDate,
  }) async {
    final dateString = asOfDate.toIso8601String().split('T').first;

    final result = await database.rawQuery('''
      SELECT 
        ca.id,
        ca.account_code,
        ca.account_name,
        ca.account_type,
        COALESCE(SUM(CASE WHEN gl.debit > 0 THEN gl.debit ELSE 0 END), 0) as total_debit,
        COALESCE(SUM(CASE WHEN gl.credit > 0 THEN gl.credit ELSE 0 END), 0) as total_credit
      FROM chart_of_accounts ca
      LEFT JOIN gl_entry_detail gl ON ca.id = gl.account_id
      WHERE gl.entry_date <= ?
      GROUP BY ca.id, ca.account_code, ca.account_name, ca.account_type
      ORDER BY ca.account_code
    ''', [dateString]);

    return result;
  }

  /// Helper method to get account balances by type
  Future<List<Map<String, dynamic>>> _getAccountBalancesByType(
    String accountType, {
    String? beforeDate,
    String? startDate,
    String? endDate,
  }) async {
    String whereClause = 'ca.account_type = ?';
    List<dynamic> whereArgs = [accountType];

    if (beforeDate != null) {
      whereClause += ' AND gl.entry_date <= ?';
      whereArgs.add(beforeDate);
    } else if (startDate != null && endDate != null) {
      whereClause += ' AND gl.entry_date BETWEEN ? AND ?';
      whereArgs.addAll([startDate, endDate]);
    }

    final result = await database.rawQuery('''
      SELECT 
        ca.id,
        ca.account_code,
        ca.account_name,
        COALESCE(SUM(gl.debit - gl.credit), 0) as balance
      FROM chart_of_accounts ca
      LEFT JOIN gl_entry_detail gl ON ca.id = gl.account_id
      WHERE $whereClause
      GROUP BY ca.id, ca.account_code, ca.account_name
      ORDER BY ca.account_code
    ''', whereArgs);

    return result;
  }
}
