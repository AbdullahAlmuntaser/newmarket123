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
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrialBalanceItem _$TrialBalanceItemFromJson(Map<String, dynamic> json) =>
    TrialBalanceItem(
      const GLAccountConverter()
          .fromJson(json['account'] as Map<String, dynamic>),
      (json['totalDebit'] as num).toDouble(),
      (json['totalCredit'] as num).toDouble(),
    );

Map<String, dynamic> _$TrialBalanceItemToJson(TrialBalanceItem instance) =>
    <String, dynamic>{
      'account': const GLAccountConverter().toJson(instance.account),
      'totalDebit': instance.totalDebit,
      'totalCredit': instance.totalCredit,
    };
