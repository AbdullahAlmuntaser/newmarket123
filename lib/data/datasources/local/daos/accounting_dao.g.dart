// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounting_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountingDaoMixin on DatabaseAccessor<AppDatabase> {}

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
