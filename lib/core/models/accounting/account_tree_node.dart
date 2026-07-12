import 'package:supermarket/data/datasources/local/app_database.dart';

class AccountTreeNode {
  final GLAccount account;
  final Decimal balance;
  final Decimal treeBalance;
  final List<AccountTreeNode> children;

  AccountTreeNode({
    required this.account,
    required this.balance,
    required this.treeBalance,
    required this.children,
  });

  bool get isLeaf => children.isEmpty;
}
