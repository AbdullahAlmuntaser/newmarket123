import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum GLAccountType { asset, liability, equity, revenue, expense, cogs, otherIncome }

class GLAccountEntity extends Equatable {
  final String id;
  final String code;
  final String name;
  final GLAccountType type;
  final String? analyticType;
  final String? parentId;
  final bool isHeader;
  final Decimal balance;
  final String? branchId;

  const GLAccountEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.analyticType,
    this.parentId,
    this.isHeader = false,
    required this.balance,
    this.branchId,
  });

  GLAccountEntity copyWith({Decimal? balance}) {
    return GLAccountEntity(
      id: id,
      code: code,
      name: name,
      type: type,
      analyticType: analyticType,
      parentId: parentId,
      isHeader: isHeader,
      balance: balance ?? this.balance,
      branchId: branchId,
    );
  }

  @override
  List<Object?> get props => [
        id, code, name, type, analyticType, parentId, isHeader, balance, branchId,
      ];
}

class GLEntryEntity extends Equatable {
  final String id;
  final DateTime date;
  final String? description;
  final String? referenceType;
  final String? referenceId;
  final Decimal exchangeRate;
  final String? branchId;
  final List<GLLineEntity> lines;

  const GLEntryEntity({
    required this.id,
    required this.date,
    this.description,
    this.referenceType,
    this.referenceId,
    required this.exchangeRate,
    this.branchId,
    this.lines = const [],
  });

  Decimal get totalDebit =>
      lines.fold(Decimal.zero, (sum, l) => sum + l.debit);
  Decimal get totalCredit =>
      lines.fold(Decimal.zero, (sum, l) => sum + l.credit);

  bool get isBalanced => totalDebit == totalCredit;

  @override
  List<Object?> get props => [
        id, date, description, referenceType, referenceId,
        exchangeRate, branchId, lines,
      ];
}

class GLLineEntity extends Equatable {
  final String id;
  final String entryId;
  final String accountId;
  final String? costCenterId;
  final Decimal debit;
  final Decimal credit;
  final String? currencyId;
  final Decimal exchangeRate;
  final String? memo;

  const GLLineEntity({
    required this.id,
    required this.entryId,
    required this.accountId,
    this.costCenterId,
    required this.debit,
    required this.credit,
    this.currencyId,
    required this.exchangeRate,
    this.memo,
  });

  @override
  List<Object?> get props => [
        id, entryId, accountId, costCenterId, debit, credit,
        currencyId, exchangeRate, memo,
      ];
}
