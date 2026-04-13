import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

part 'accounting_dao.g.dart';

class GLAccountConverter
    implements JsonConverter<GLAccount, Map<String, dynamic>> {
  const GLAccountConverter();

  @override
  GLAccount fromJson(Map<String, dynamic> json) => GLAccount.fromJson(json);

  @override
  Map<String, dynamic> toJson(GLAccount object) => object.toJson();
}

class AccountType {
  static const String asset = 'ASSET';
  static const String liability = 'LIABILITY';
  static const String equity = 'EQUITY';
  static const String revenue = 'REVENUE';
  static const String expense = 'EXPENSE';
}

@JsonSerializable(explicitToJson: true)
class TrialBalanceItem {
  @GLAccountConverter()
  final GLAccount account;
  final double totalDebit;
  final double totalCredit;

  double get netBalance {
    if (account.type == AccountType.asset ||
        account.type == AccountType.expense) {
      return totalDebit - totalCredit;
    } else {
      return totalCredit - totalDebit;
    }
  }

  TrialBalanceItem(this.account, this.totalDebit, this.totalCredit);

  factory TrialBalanceItem.fromJson(Map<String, dynamic> json) =>
      _$TrialBalanceItemFromJson(json);
  Map<String, dynamic> toJson() => _$TrialBalanceItemToJson(this);
}

class GLLineWithAccount {
  final GLLine line;
  final GLAccount account;
  GLLineWithAccount(this.line, this.account);
}

@DriftAccessor(tables: [GLAccounts, CostCenters, GLEntries, GLLines, Reconciliations])
class AccountingDao extends DatabaseAccessor<AppDatabase>
    with _$AccountingDaoMixin {
  AccountingDao(super.db);

  // --- GL Accounts ---
  Future<List<GLAccount>> getAllAccounts() => (select(
    gLAccounts,
  )..orderBy([(t) => OrderingTerm(expression: t.code)])).get();

  Stream<List<GLAccount>> watchAccounts() => (select(
    gLAccounts,
  )..orderBy([(t) => OrderingTerm(expression: t.code)])).watch();

  Future<GLAccount?> getAccountByCode(String code) =>
      (select(gLAccounts)..where((t) => t.code.equals(code))).getSingleOrNull();

  Future<GLAccount?> getAccountById(String id) =>
      (select(gLAccounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createAccount(GLAccountsCompanion account) =>
      into(gLAccounts).insert(account);

  Future<bool> updateAccount(GLAccount account) =>
      update(gLAccounts).replace(account);

  // New: Get accounts by type
  Future<List<GLAccount>> getAccountsByType(String type) =>
      (select(gLAccounts)..where((tbl) => tbl.type.equals(type))).get();

  // --- Cost Centers ---
  Future<List<CostCenter>> getAllCostCenters() => (select(costCenters)).get();
  Stream<List<CostCenter>> watchCostCenters() => (select(costCenters)).watch();
  Future<int> createCostCenter(CostCentersCompanion cc) => into(costCenters).insert(cc);
  Future<bool> updateCostCenter(CostCenter cc) => update(costCenters).replace(cc);

  // --- GL Entries ---
  Future<void> createEntry(
    GLEntriesCompanion entry,
    List<GLLinesCompanion> lines,
  ) {
    return transaction(() async {
      final entryRow = await into(gLEntries).insertReturning(entry);
      for (var line in lines) {
        final lineRow = await into(gLLines).insertReturning(
          line.copyWith(entryId: Value(entryRow.id)),
        );

        // Update AccountTransactions for running balance
        await _updateAccountRunningBalance(lineRow, entryRow);
      }
    });
  }

  Future<void> _updateAccountRunningBalance(GLLine line, GLEntry entry) async {
    // Get last running balance for this account
    final lastTrans = await (select(db.accountTransactions)
          ..where((t) => t.accountId.equals(line.accountId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();

    double lastBalance = lastTrans?.runningBalance ?? 0;

    final account = await (select(gLAccounts)
          ..where((a) => a.id.equals(line.accountId)))
        .getSingle();

    double newBalance;
    // ASSET and EXPENSE accounts increase with Debit, decrease with Credit.
    // LIABILITY, EQUITY, and REVENUE accounts increase with Credit, decrease with Debit.
    if ([AccountType.asset, AccountType.expense].contains(account.type)) {
      newBalance = lastBalance + line.debit - line.credit;
    } else {
      newBalance = lastBalance + line.credit - line.debit;
    }

    await into(db.accountTransactions).insert(
      AccountTransactionsCompanion.insert(
        accountId: line.accountId,
        type: entry.referenceType ?? 'MANUAL',
        referenceId: Value(entry.referenceId),
        debit: Value(line.debit),
        credit: Value(line.credit),
        runningBalance: Value(newBalance),
        date: Value(entry.date),
      ),
    );
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
    ])..where(gLLines.entryId.equals(entryId));

    final rows = await query.get();
    return rows.map((row) {
      return GLLineWithAccount(
        row.readTable(gLLines),
        row.readTable(gLAccounts),
      );
    }).toList();
  }

  // New: Get GL entries within a date range
  Future<List<GLEntry>> getGLEntriesInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return (select(
      gLEntries,
    )..where((tbl) => tbl.date.isBetweenValues(startDate, endDate))).get();
  }

  // --- Reconciliations ---
  Future<int> createReconciliation(ReconciliationsCompanion rec) =>
      into(reconciliations).insert(rec);

  Stream<List<Reconciliation>> watchReconciliations() =>
      (select(reconciliations)..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
          .watch();

  // --- Reports ---
  Future<List<TrialBalanceItem>> getTrialBalance() async {
    final accounts = await getAllAccounts();
    final items = <TrialBalanceItem>[];
    for (final account in accounts) {
      if (account.isHeader) continue;

      final debitSum = gLLines.debit.sum();
      final creditSum = gLLines.credit.sum();
      final query = selectOnly(gLLines)
        ..addColumns([debitSum, creditSum])
        ..where(gLLines.accountId.equals(account.id));

      final result = await query.getSingle();
      final debit = result.read(debitSum) ?? 0.0;
      final credit = result.read(creditSum) ?? 0.0;

      items.add(TrialBalanceItem(account, debit, credit));
    }
    return items;
  }

  Future<double> getAccountBalance(String accountId) async {
    final account = await getAccountById(accountId);
    if (account == null) return 0.0;

    final debitSum = gLLines.debit.sum();
    final creditSum = gLLines.credit.sum();

    final query = selectOnly(gLLines)
      ..addColumns([debitSum, creditSum])
      ..where(gLLines.accountId.equals(accountId));

    final result = await query.getSingleOrNull();

    if (result == null) {
      return 0.0;
    }

    final debit = result.read(debitSum) ?? 0.0;
    final credit = result.read(creditSum) ?? 0.0;

    if (account.type == AccountType.asset ||
        account.type == AccountType.expense) {
      return debit - credit;
    } else {
      return credit - debit;
    }
  }

  // New: Get account balance up to a specific date
  Future<double> getAccountBalanceAsOfDate(
    String accountId,
    DateTime asOfDate,
  ) async {
    final account = await getAccountById(accountId);
    if (account == null) return 0.0;

    final debitSum = gLLines.debit.sum();
    final creditSum = gLLines.credit.sum();

    final query =
        selectOnly(gLLines).join([
            innerJoin(gLEntries, gLEntries.id.equalsExp(gLLines.entryId)),
          ])
          ..addColumns([debitSum, creditSum])
          ..where(
            gLLines.accountId.equals(accountId) &
                gLEntries.date.isSmallerOrEqualValue(asOfDate),
          );

    final result = await query.getSingleOrNull();

    if (result == null) {
      return 0.0;
    }

    final debit = result.read(debitSum) ?? 0.0;
    final credit = result.read(creditSum) ?? 0.0;

    if (account.type == AccountType.asset ||
        account.type == AccountType.expense) {
      return debit - credit;
    } else {
      return credit - debit;
    }
  }

  // New: Get account balance movement in a specific date range
  Future<double> getAccountBalanceInRange(
    String accountId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final account = await getAccountById(accountId);
    if (account == null) return 0.0;

    final debitSum = gLLines.debit.sum();
    final creditSum = gLLines.credit.sum();

    final query =
        selectOnly(gLLines).join([
            innerJoin(gLEntries, gLEntries.id.equalsExp(gLLines.entryId)),
          ])
          ..addColumns([debitSum, creditSum])
          ..where(
            gLLines.accountId.equals(accountId) &
                gLEntries.date.isBetweenValues(startDate, endDate),
          );

    final result = await query.getSingleOrNull();

    if (result == null) {
      return 0.0;
    }

    final debit = result.read(debitSum) ?? 0.0;
    final credit = result.read(creditSum) ?? 0.0;

    if (account.type == AccountType.asset ||
        account.type == AccountType.expense) {
      return debit - credit;
    } else {
      return credit - debit;
    }
  }

  // New: Get all account balances as of a specific date efficiently
  Future<List<TrialBalanceItem>> getAllAccountBalancesAsOfDate(
    DateTime asOfDate,
  ) async {
    final allAccounts = await getAllAccounts();

    final debitSum = gLLines.debit.sum();
    final creditSum = gLLines.credit.sum();

    final query =
        selectOnly(gLLines).join([
            innerJoin(gLEntries, gLEntries.id.equalsExp(gLLines.entryId)),
          ])
          ..addColumns([gLLines.accountId, debitSum, creditSum])
          ..where(gLEntries.date.isSmallerOrEqualValue(asOfDate));

    query.groupBy([gLLines.accountId]);

    final rows = await query.get();
    final Map<String, ({double debit, double credit})> balanceMap = {
      for (final row in rows)
        row.read(gLLines.accountId)!: (
          debit: row.read(debitSum) ?? 0.0,
          credit: row.read(creditSum) ?? 0.0,
        ),
    };

    return allAccounts.map((account) {
      final balance = balanceMap[account.id] ?? (debit: 0.0, credit: 0.0);
      return TrialBalanceItem(account, balance.debit, balance.credit);
    }).toList();
  }

  // New: Get all GL lines for a specific account within a date range
  Future<List<GLLine>> getGLLinesForAccountInDateRange(
    String accountId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return (select(gLLines).join([
          innerJoin(gLEntries, gLEntries.id.equalsExp(gLLines.entryId)),
        ])..where(
          gLLines.accountId.equals(accountId) &
              gLEntries.date.isBetweenValues(startDate, endDate),
        ))
        .map((row) => row.readTable(gLLines))
        .get();
  }

  // New: Get all GLLines with their associated GLEntries within a date range
  Future<List<GLLineWithAccount>> getGLLinesWithEntriesInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = select(gLLines).join([
      innerJoin(gLEntries, gLEntries.id.equalsExp(gLLines.entryId)),
      innerJoin(gLAccounts, gLAccounts.id.equalsExp(gLLines.accountId)),
    ])..where(gLEntries.date.isBetweenValues(startDate, endDate));

    final rows = await query.get();
    return rows.map((row) {
      return GLLineWithAccount(
        row.readTable(gLLines),
        row.readTable(gLAccounts),
      );
    }).toList();
  }
}
