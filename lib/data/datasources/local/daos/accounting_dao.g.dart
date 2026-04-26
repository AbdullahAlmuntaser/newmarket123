// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounting_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountingDaoMixin on DatabaseAccessor<AppDatabase> {
  $GLAccountsTable get gLAccounts => attachedDatabase.gLAccounts;
  $CostCentersTable get costCenters => attachedDatabase.costCenters;
  $GLEntriesTable get gLEntries => attachedDatabase.gLEntries;
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $GLLinesTable get gLLines => attachedDatabase.gLLines;
  $ReconciliationsTable get reconciliations => attachedDatabase.reconciliations;
  $AccountingPeriodsTable get accountingPeriods =>
      attachedDatabase.accountingPeriods;
  AccountingDaoManager get managers => AccountingDaoManager(this);
}

class AccountingDaoManager {
  final _$AccountingDaoMixin _db;
  AccountingDaoManager(this._db);
  $$GLAccountsTableTableManager get gLAccounts =>
      $$GLAccountsTableTableManager(_db.attachedDatabase, _db.gLAccounts);
  $$CostCentersTableTableManager get costCenters =>
      $$CostCentersTableTableManager(_db.attachedDatabase, _db.costCenters);
  $$GLEntriesTableTableManager get gLEntries =>
      $$GLEntriesTableTableManager(_db.attachedDatabase, _db.gLEntries);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db.attachedDatabase, _db.currencies);
  $$GLLinesTableTableManager get gLLines =>
      $$GLLinesTableTableManager(_db.attachedDatabase, _db.gLLines);
  $$ReconciliationsTableTableManager get reconciliations =>
      $$ReconciliationsTableTableManager(
        _db.attachedDatabase,
        _db.reconciliations,
      );
  $$AccountingPeriodsTableTableManager get accountingPeriods =>
      $$AccountingPeriodsTableTableManager(
        _db.attachedDatabase,
        _db.accountingPeriods,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrialBalanceItem _$TrialBalanceItemFromJson(Map<String, dynamic> json) =>
    TrialBalanceItem(
      const GLAccountConverter().fromJson(
        json['account'] as Map<String, dynamic>,
      ),
      (json['totalDebit'] as num).toDouble(),
      (json['totalCredit'] as num).toDouble(),
    );

Map<String, dynamic> _$TrialBalanceItemToJson(TrialBalanceItem instance) =>
    <String, dynamic>{
      'account': const GLAccountConverter().toJson(instance.account),
      'totalDebit': instance.totalDebit,
      'totalCredit': instance.totalCredit,
    };
