import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/constants/account_types.dart';
import '../mixins/sync_log_mixin.dart';

part 'accounting_dao.g.dart';

class TrialBalanceItem {
  final GLAccount account;
  final Decimal totalDebit;
  final Decimal totalCredit;

  Decimal get netBalance {
    if (account.type == AccountType.asset ||
        account.type == AccountType.expense) {
      return totalDebit - totalCredit;
    } else {
      return totalCredit - totalDebit;
    }
  }

  TrialBalanceItem(this.account, this.totalDebit, this.totalCredit);

  factory TrialBalanceItem.fromJson(Map<String, dynamic> json) =>
      TrialBalanceItem(
        GLAccount.fromJson(json['account'] as Map<String, dynamic>),
        Decimal.parse(json['totalDebit'].toString()),
        Decimal.parse(json['totalCredit'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'account': account.toJson(),
        'totalDebit': totalDebit.toString(),
        'totalCredit': totalCredit.toString(),
      };
}

class GLLineWithAccount {
  final GLLine line;
  final GLAccount account;
  GLLineWithAccount(this.line, this.account);
}

class IncomeStatement {
  final Decimal totalRevenue;
  final Decimal costOfGoodsSold;
  final Decimal grossProfit;
  final Decimal totalExpenses;
  final Decimal netIncome;

  IncomeStatement({
    required this.totalRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netIncome,
  });
}

class BalanceSheet {
  final List<TrialBalanceItem> assets;
  final List<TrialBalanceItem> liabilities;
  final List<TrialBalanceItem> equity;
  final Decimal totalAssets;
  final Decimal totalLiabilities;
  final Decimal totalEquity;

  BalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
  });
}

@DriftAccessor(
  tables: [
    GLAccounts,
    CostCenters,
    GLEntries,
    GLLines,
    Reconciliations,
    AccountingPeriods,
    AccountTransactions,
    SyncQueue,
  ],
)
class AccountingDao extends DatabaseAccessor<AppDatabase>
    with _$AccountingDaoMixin, SyncLogMixin {
  AccountingDao(super.db);

  Future<bool> isDateInClosedPeriod(DateTime date) async {
    final query = select(db.accountingPeriods)
      ..where((p) =>
          p.isClosed.equals(true) &
          p.startDate.isSmallerOrEqual(Variable(date)) &
          p.endDate.isBiggerOrEqual(Variable(date)));
    final closedPeriod = await query.getSingleOrNull();
    return closedPeriod != null;
  }

  Future<void> closeAccountingPeriod(String periodId, {String? userId}) async {
    await (update(db.accountingPeriods)..where((t) => t.id.equals(periodId)))
        .write(
      AccountingPeriodsCompanion(
        isClosed: const Value(true),
        closedAt: Value(DateTime.now()),
        closedBy: Value(userId),
        status: const Value('CLOSED'),
      ),
    );
  }

  // --- GL Accounts ---
  Future<List<GLAccount>> getAllAccounts() => (select(
        gLAccounts,
      )..orderBy([(t) => OrderingTerm(expression: t.code)]))
          .get();

  Stream<List<GLAccount>> watchAccounts() => (select(
        gLAccounts,
      )..orderBy([(t) => OrderingTerm(expression: t.code)]))
          .watch();

  Future<GLAccount?> getAccountByCode(String code) =>
      (select(gLAccounts)..where((t) => t.code.equals(code))).getSingleOrNull();

  Future<GLAccount?> getAccountById(String id) =>
      (select(gLAccounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> createAccount(GLAccountsCompanion account) async {
    final row = await into(gLAccounts).insertReturning(account);
    await logSyncOperation(
      table: 'gl_accounts',
      entityId: row.id,
      operation: 'CREATE',
    );
    return row.id;
  }

  Future<bool> updateAccount(GLAccount account) async {
    final result = await update(gLAccounts).replace(account);
    if (result) {
      await logSyncOperation(
        table: 'gl_accounts',
        entityId: account.id,
        operation: 'UPDATE',
      );
    }
    return result;
  }

  Future<List<GLAccount>> getAccountsByType(String type) =>
      (select(gLAccounts)..where((tbl) => tbl.type.equals(type))).get();

  // --- Cost Centers ---
  Future<List<CostCenter>> getAllCostCenters() => (select(costCenters)).get();
  Stream<List<CostCenter>> watchCostCenters() => (select(costCenters)).watch();
  Future<String> createCostCenter(CostCentersCompanion cc) async {
    final row = await into(costCenters).insertReturning(cc);
    return row.id;
  }

  Future<bool> updateCostCenter(CostCenter cc) =>
      update(costCenters).replace(cc);

  Future<void> createEntry(
    GLEntriesCompanion entry,
    List<GLLinesCompanion> lines,
  ) {
    return transaction(() async {
      if (entry.referenceType.present &&
          entry.referenceType.value != null &&
          entry.referenceId.present &&
          entry.referenceId.value != null) {
        final duplicate = await (select(gLEntries)
              ..where((e) => e.referenceType.equals(entry.referenceType.value!))
              ..where((e) => e.referenceId.equals(entry.referenceId.value!)))
            .getSingleOrNull();
        if (duplicate != null) {
          return;
        }
      }

      // Validate accounting balance: Sum of Debits == Sum of Credits
      Decimal totalDebit = Decimal.zero;
      Decimal totalCredit = Decimal.zero;
      for (var line in lines) {
        totalDebit += line.debit.value;
        totalCredit += line.credit.value;
      }
      if (totalDebit != totalCredit) {
        throw Exception(
          'القيد المحاسبي غير متوازن! (المدين: $totalDebit، الدائن: $totalCredit)',
        );
      }

      final entryRow = await into(gLEntries).insertReturning(entry);

      await logSyncOperation(
        table: 'gl_entries',
        entityId: entryRow.id,
        operation: 'CREATE',
      );

      for (var line in lines) {
        final lineToInsert = line.copyWith(
          entryId: Value(entryRow.id),
          branchId:
              line.branchId.present ? line.branchId : Value(entryRow.branchId),
        );

        final lineRow = await into(gLLines).insertReturning(lineToInsert);

        await _recordAccountTransaction(lineRow, entryRow);
      }
    });
  }

  Future<void> _recordAccountTransaction(GLLine line, GLEntry entry) async {
    await into(db.accountTransactions).insert(
      AccountTransactionsCompanion.insert(
        accountId: line.accountId,
        type: entry.referenceType ?? 'MANUAL',
        referenceId: Value(entry.referenceId),
        debit: Value(line.debit),
        credit: Value(line.credit),
        date: Value(entry.date),
      ),
    );
  }

  // --- Decimal-based Account Balance Calculation ---
  Future<Decimal> getAccountBalance(String accountId,
      {String? branchId}) async {
    final account = await getAccountById(accountId);
    if (account == null) return Decimal.zero;

    var query = db.select(db.accountTransactions).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.accountTransactions.referenceId)),
    ])
      ..where(db.accountTransactions.accountId.equals(accountId));

    if (branchId != null) {
      query = query..where(db.accountTransactions.branchId.equals(branchId));
    }

    final rows = await query.get();
    if (rows.isEmpty) return Decimal.zero;

    Decimal debit = Decimal.zero;
    Decimal credit = Decimal.zero;
    for (final row in rows) {
      debit += row.readTable(db.accountTransactions).debit;
      credit += row.readTable(db.accountTransactions).credit;
    }

    if ([AccountType.asset, AccountType.expense].contains(account.type)) {
      return debit - credit;
    } else {
      return credit - debit;
    }
  }

  Stream<List<GLEntry>> watchRecentEntries({int limit = 50}) {
    return (select(gLEntries)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<GLLineWithAccount>> getLinesForEntry(String entryId) async {
    final query = select(gLLines).join([
      innerJoin(gLAccounts, gLAccounts.id.equalsExp(gLLines.accountId)),
    ])
      ..where(gLLines.entryId.equals(entryId));

    final rows = await query.get();
    return rows.map((row) {
      return GLLineWithAccount(
        row.readTable(gLLines),
        row.readTable(gLAccounts),
      );
    }).toList();
  }

  Future<List<GLEntry>> getGLEntriesInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return (select(
      gLEntries,
    )..where((tbl) =>
            tbl.date.isBetween(Variable(startDate), Variable(endDate))))
        .get();
  }

  // --- Posting Profiles ---
  Future<List<PostingProfile>> getAllPostingProfiles() =>
      select(db.postingProfiles).get();

  Stream<List<PostingProfile>> watchPostingProfiles() =>
      select(db.postingProfiles).watch();

  Future<bool> updatePostingProfile(PostingProfile profile) =>
      update(db.postingProfiles).replace(profile);

  Future<int> createPostingProfile(PostingProfilesCompanion profile) =>
      into(db.postingProfiles).insert(profile);

  Future<int> deletePostingProfile(String id) =>
      (delete(db.postingProfiles)..where((t) => t.id.equals(id))).go();

  // --- Reports (all Decimal-based) ---
  Future<List<TrialBalanceItem>> getTrialBalance({String? branchId}) async {
    final accounts = await getAllAccounts();

    var query = db.select(db.gLLines).join([
      innerJoin(db.gLEntries, db.gLEntries.id.equalsExp(db.gLLines.entryId)),
    ]);

    if (branchId != null) {
      query = query..where(db.gLLines.branchId.equals(branchId));
    }

    final rows = await query.get();

    final Map<String, ({Decimal debit, Decimal credit})> totals = {};
    for (final row in rows) {
      final line = row.readTable(db.gLLines);
      final entry =
          totals[line.accountId] ?? (debit: Decimal.zero, credit: Decimal.zero);
      totals[line.accountId] = (
        debit: entry.debit + line.debit,
        credit: entry.credit + line.credit,
      );
    }

    final items = <TrialBalanceItem>[];
    for (final account in accounts) {
      if (account.isHeader) continue;
      final t =
          totals[account.id] ?? (debit: Decimal.zero, credit: Decimal.zero);
      items.add(TrialBalanceItem(account, t.debit, t.credit));
    }
    return items;
  }

  // --- Decimal-based Account Balance As Of Date ---
  Future<Decimal> getAccountBalanceAsOfDate(
    String accountId,
    DateTime asOfDate, {
    String? branchId,
  }) async {
    final account = await getAccountById(accountId);
    if (account == null) return Decimal.zero;

    var predicate = gLLines.accountId.equals(accountId) &
        gLEntries.date.isSmallerOrEqual(Variable(asOfDate));

    if (branchId != null) {
      predicate = predicate & gLLines.branchId.equals(branchId);
    }

    final rows = await (select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
          ..where(predicate))
        .get();

    if (rows.isEmpty) return Decimal.zero;

    Decimal debit = Decimal.zero;
    Decimal credit = Decimal.zero;
    for (final row in rows) {
      debit += row.readTable(gLLines).debit;
      credit += row.readTable(gLLines).credit;
    }

    if (account.type == AccountType.asset ||
        account.type == AccountType.expense) {
      return debit - credit;
    } else {
      return credit - debit;
    }
  }

  // --- Decimal-based Account Balance In Range ---
  Future<Decimal> getAccountBalanceInRange(
    String accountId,
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) async {
    final account = await getAccountById(accountId);
    if (account == null) return Decimal.zero;

    var predicate = gLLines.accountId.equals(accountId) &
        gLEntries.date.isBetween(Variable(startDate), Variable(endDate));

    if (branchId != null) {
      predicate = predicate & gLLines.branchId.equals(branchId);
    }

    final rows = await (select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
          ..where(predicate))
        .get();

    if (rows.isEmpty) return Decimal.zero;

    Decimal debit = Decimal.zero;
    Decimal credit = Decimal.zero;
    for (final row in rows) {
      debit += row.readTable(gLLines).debit;
      credit += row.readTable(gLLines).credit;
    }

    if (account.type == AccountType.asset ||
        account.type == AccountType.expense) {
      return debit - credit;
    } else {
      return credit - debit;
    }
  }

  // --- Decimal-based All Account Balances As Of Date ---
  Future<List<TrialBalanceItem>> getAllAccountBalancesAsOfDate(
    DateTime asOfDate, {
    String? branchId,
  }) async {
    final allAccounts = await getAllAccounts();

    var predicate = gLEntries.date.isSmallerOrEqual(Variable(asOfDate));
    if (branchId != null) {
      predicate = predicate & gLLines.branchId.equals(branchId);
    }

    final rows = await (select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
          ..where(predicate))
        .get();

    final Map<String, ({Decimal debit, Decimal credit})> balanceMap = {};
    for (final row in rows) {
      final line = row.readTable(gLLines);
      final entry = balanceMap[line.accountId] ??
          (debit: Decimal.zero, credit: Decimal.zero);
      balanceMap[line.accountId] = (
        debit: entry.debit + line.debit,
        credit: entry.credit + line.credit,
      );
    }

    return allAccounts.map((account) {
      final balance =
          balanceMap[account.id] ?? (debit: Decimal.zero, credit: Decimal.zero);
      return TrialBalanceItem(account, balance.debit, balance.credit);
    }).toList();
  }

  // --- Decimal-based All Account Balances In Date Range ---
  Future<List<TrialBalanceItem>> getAllAccountBalancesInRange(
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) async {
    final allAccounts = await getAllAccounts();

    var predicate =
        gLEntries.date.isBetween(Variable(startDate), Variable(endDate));
    if (branchId != null) {
      predicate = predicate & gLLines.branchId.equals(branchId);
    }

    final rows = await (select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
          ..where(predicate))
        .get();

    final Map<String, ({Decimal debit, Decimal credit})> balanceMap = {};
    for (final row in rows) {
      final line = row.readTable(gLLines);
      final entry = balanceMap[line.accountId] ??
          (debit: Decimal.zero, credit: Decimal.zero);
      balanceMap[line.accountId] = (
        debit: entry.debit + line.debit,
        credit: entry.credit + line.credit,
      );
    }

    return allAccounts.map((account) {
      final balance =
          balanceMap[account.id] ?? (debit: Decimal.zero, credit: Decimal.zero);
      return TrialBalanceItem(account, balance.debit, balance.credit);
    }).toList();
  }

  // --- Get GL Lines For Account In Date Range ---
  Future<List<GLLine>> getGLLinesForAccountInDateRange(
    String accountId,
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) {
    var predicate = gLLines.accountId.equals(accountId) &
        gLEntries.date.isBetween(Variable(startDate), Variable(endDate));

    if (branchId != null) {
      predicate = predicate & gLLines.branchId.equals(branchId);
    }

    return (select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(db.gLLines.entryId)),
    ])
          ..where(predicate))
        .map((row) => row.readTable(gLLines))
        .get();
  }

  // --- Get All GL Lines With Entries In Date Range ---
  Future<List<GLLineWithAccount>> getGLLinesWithEntriesInDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) async {
    var predicate =
        gLEntries.date.isBetween(Variable(startDate), Variable(endDate));

    if (branchId != null) {
      predicate = predicate & gLLines.branchId.equals(branchId);
    }

    final query = select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(db.gLLines.entryId)),
      innerJoin(gLAccounts, gLAccounts.id.equalsExp(db.gLLines.accountId)),
    ])
      ..where(predicate);

    final rows = await query.get();
    return rows.map((row) {
      return GLLineWithAccount(
        row.readTable(gLLines),
        row.readTable(gLAccounts),
      );
    }).toList();
  }

  // --- Income Statement (Decimal-based) ---
  Future<IncomeStatement> getIncomeStatement({
    required DateTime startDate,
    required DateTime endDate,
    String? branchId,
  }) async {
    final allBalances = await getAllAccountBalancesInRange(
      startDate,
      endDate,
      branchId: branchId,
    );

    final accountByCode = <String, Decimal>{};
    for (final item in allBalances) {
      accountByCode[item.account.code] = item.netBalance;
    }

    Decimal totalRevenue = Decimal.zero;
    Decimal totalExpenses = Decimal.zero;
    for (final item in allBalances) {
      if (item.account.type == AccountType.revenue) {
        totalRevenue += item.netBalance;
      } else if (item.account.type == AccountType.expense) {
        totalExpenses += item.netBalance;
      }
    }

    final Decimal costOfGoodsSold = accountByCode['5010'] ?? Decimal.zero;

    final Decimal operatingExpenses = totalExpenses - costOfGoodsSold;

    return IncomeStatement(
      totalRevenue: totalRevenue,
      costOfGoodsSold: costOfGoodsSold,
      grossProfit: totalRevenue - costOfGoodsSold,
      totalExpenses: operatingExpenses,
      netIncome: totalRevenue - costOfGoodsSold - operatingExpenses,
    );
  }

  // --- Balance Sheet (Decimal-based) ---
  Future<BalanceSheet> getBalanceSheet(
      {DateTime? asOfDate, String? branchId}) async {
    final date = asOfDate ?? DateTime.now();
    final trialBalance =
        await getAllAccountBalancesAsOfDate(date, branchId: branchId);

    final assets = trialBalance
        .where((item) => item.account.type == AccountType.asset)
        .toList();
    final liabilities = trialBalance
        .where((item) => item.account.type == AccountType.liability)
        .toList();
    final equity = trialBalance
        .where((item) => item.account.type == AccountType.equity)
        .toList();

    Decimal totalAssets =
        assets.fold(Decimal.zero, (sum, item) => sum + item.netBalance);
    Decimal totalLiabilities =
        liabilities.fold(Decimal.zero, (sum, item) => sum + item.netBalance);
    Decimal totalEquity =
        equity.fold(Decimal.zero, (sum, item) => sum + item.netBalance);

    return BalanceSheet(
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      totalEquity: totalEquity,
    );
  }

  // --- Expenses By Cost Center ---
  Future<List<CostCenterExpense>> getExpensesByCostCenter({
    required DateTime startDate,
    required DateTime endDate,
    String? branchId,
  }) async {
    var predicate =
        gLEntries.date.isBetween(Variable(startDate), Variable(endDate));

    if (branchId != null) {
      predicate = predicate & gLLines.branchId.equals(branchId);
    }

    final rows = await (select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(gLLines.entryId)),
      innerJoin(gLAccounts, gLAccounts.id.equalsExp(gLLines.accountId)),
      leftOuterJoin(
          costCenters, costCenters.id.equalsExp(gLLines.costCenterId)),
    ])
          ..where(predicate)
          ..where(gLAccounts.type.equals(AccountType.expense)))
        .get();

    final Map<String, Decimal> ccTotals = {};
    for (final row in rows) {
      final line = row.readTable(gLLines);
      final ccName =
          row.readTableOrNull(costCenters)?.name ?? 'بدون مركز تكلفة';
      ccTotals[ccName] =
          (ccTotals[ccName] ?? Decimal.zero) + line.debit - line.credit;
    }

    return ccTotals.entries
        .map((e) => CostCenterExpense(name: e.key, total: e.value))
        .toList();
  }
}

class CostCenterExpense {
  final String name;
  final Decimal total;
  CostCenterExpense({required this.name, required this.total});
}
