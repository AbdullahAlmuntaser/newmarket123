class Partner {
  final String id;
  final String name;
  final bool isCustomer;
  final double creditLimit;
  final int paymentTermsDays;
  final double openingBalance;

  const Partner({
    required this.id,
    required this.name,
    required this.isCustomer,
    required this.creditLimit,
    required this.paymentTermsDays,
    this.openingBalance = 0.0,
  });
}
