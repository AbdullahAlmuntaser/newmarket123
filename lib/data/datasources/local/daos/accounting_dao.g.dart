// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounting_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountingDaoMixin on DatabaseAccessor<AppDatabase> {
  $BranchesTable get branches => attachedDatabase.branches;
  $GLAccountsTable get gLAccounts => attachedDatabase.gLAccounts;
  $CostCentersTable get costCenters => attachedDatabase.costCenters;
  $GLEntriesTable get gLEntries => attachedDatabase.gLEntries;
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $GLLinesTable get gLLines => attachedDatabase.gLLines;
  $ReconciliationsTable get reconciliations => attachedDatabase.reconciliations;
  $AccountingPeriodsTable get accountingPeriods =>
      attachedDatabase.accountingPeriods;
  $AccountTransactionsTable get accountTransactions =>
      attachedDatabase.accountTransactions;
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
}
