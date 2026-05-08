enum DocumentStatus {
  draft,
  posted,
  received,
  cancelled,
  paid,
  partial,
  voided;

  String get displayName => switch (this) {
        DocumentStatus.draft => 'Draft',
        DocumentStatus.posted => 'Posted',
        DocumentStatus.received => 'Received',
        DocumentStatus.cancelled => 'Cancelled',
        DocumentStatus.paid => 'Paid',
        DocumentStatus.partial => 'Partial',
        DocumentStatus.voided => 'Voided',
      };
}

enum PaymentMethod {
  cash,
  bank,
  check;

  String get name => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.bank => 'Card',
        PaymentMethod.check => 'Check',
      };
}

enum TransactionType {
  sale,
  purchase,
  returnItem,
  transfer,
  adjustment,
  initial,
  paymentIn,
  paymentOut,
}

enum AccountType { asset, liability, equity, revenue, expense }
