class Shift {
  final String id;
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  final double openingBalance;
  double closingBalance;

  Shift({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.openingBalance,
    this.closingBalance = 0.0,
  });
}
