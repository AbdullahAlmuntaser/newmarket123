import 'package:supermarket/data/datasources/local/app_database.dart';

class BalanceSheetItem {
  final GLAccount account;
  final Decimal balance;

  BalanceSheetItem(this.account, this.balance);

  factory BalanceSheetItem.fromJson(Map<String, dynamic> json) =>
      BalanceSheetItem(
        GLAccount.fromJson(json['account'] as Map<String, dynamic>),
        Decimal.fromJson(json['balance'] as String),
      );

  Map<String, dynamic> toJson() => {
        'account': account.toJson(),
        'balance': balance,
      };
}
