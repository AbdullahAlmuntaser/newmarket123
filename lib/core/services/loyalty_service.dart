import 'dart:convert';

import 'package:supermarket/core/services/app_config_service.dart';

class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.customerId,
    required this.points,
    required this.reason,
    required this.createdAt,
  });

  final String customerId;
  final int points;
  final String reason;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'points': points,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      customerId: json['customerId'] as String,
      points: json['points'] as int,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class LoyaltyService {
  LoyaltyService(this._configService);

  static const String keyBalances = 'loyalty_balances_json';
  static const String keyTransactions = 'loyalty_transactions_json';
  static const double defaultAmountPerPoint = 10;

  final AppConfigService _configService;

  Future<Map<String, int>> getBalances() async {
    final raw = await _configService.getString(keyBalances);
    if (raw == null || raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
  }

  Future<int> getBalance(String customerId) async {
    final balances = await getBalances();
    return balances[customerId] ?? 0;
  }

  Future<int> calculateEarnedPoints(
    double amount, {
    double amountPerPoint = defaultAmountPerPoint,
  }) async {
    if (amount <= 0 || amountPerPoint <= 0) return 0;
    return (amount / amountPerPoint).floor();
  }

  Future<int> awardPoints({
    required String customerId,
    required double amount,
    String reason = 'sale',
  }) async {
    final points = await calculateEarnedPoints(amount);
    if (points <= 0) return await getBalance(customerId);
    return adjustPoints(customerId: customerId, points: points, reason: reason);
  }

  Future<int> redeemPoints({
    required String customerId,
    required int points,
    String reason = 'redeem',
  }) async {
    if (points <= 0) return await getBalance(customerId);
    final balance = await getBalance(customerId);
    if (balance < points) {
      throw Exception('Insufficient loyalty points');
    }
    return adjustPoints(customerId: customerId, points: -points, reason: reason);
  }

  Future<int> adjustPoints({
    required String customerId,
    required int points,
    required String reason,
  }) async {
    final balances = await getBalances();
    final nextBalance = (balances[customerId] ?? 0) + points;
    balances[customerId] = nextBalance < 0 ? 0 : nextBalance;
    await _saveBalances(balances);

    final transactions = await listTransactions();
    transactions.insert(
      0,
      LoyaltyTransaction(
        customerId: customerId,
        points: points,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );
    await _saveTransactions(transactions.take(200).toList());
    return balances[customerId] ?? 0;
  }

  Future<List<LoyaltyTransaction>> listTransactions({String? customerId}) async {
    final raw = await _configService.getString(keyTransactions);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final transactions = decoded
        .map((item) => LoyaltyTransaction.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (customerId == null) return transactions;
    return transactions.where((item) => item.customerId == customerId).toList();
  }

  Future<void> _saveBalances(Map<String, int> balances) async {
    await _configService.setString(keyBalances, jsonEncode(balances));
  }

  Future<void> _saveTransactions(List<LoyaltyTransaction> transactions) async {
    await _configService.setString(
      keyTransactions,
      jsonEncode(transactions.map((item) => item.toJson()).toList()),
    );
  }
}
