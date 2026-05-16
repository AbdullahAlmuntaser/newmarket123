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

enum TaxType {
  none,
  standard,
  reduced,
  zero,
  exempt;

  String get displayName => switch (this) {
        TaxType.none => 'None',
        TaxType.standard => 'Standard Rate',
        TaxType.reduced => 'Reduced Rate',
        TaxType.zero => 'Zero Rate',
        TaxType.exempt => 'Exempt',
      };

  String get displayNameAr => switch (this) {
        TaxType.none => 'بدون ضريبة',
        TaxType.standard => 'نسبة عامة',
        TaxType.reduced => 'نسبة مخفضة',
        TaxType.zero => 'صفر',
        TaxType.exempt => 'معفى',
      };
}

enum CurrencyType {
  sar,
  usd,
  eur,
  gbp,
  aed,
  other;

  String get displayName => switch (this) {
        CurrencyType.sar => 'Saudi Riyal (SAR)',
        CurrencyType.usd => 'US Dollar (USD)',
        CurrencyType.eur => 'Euro (EUR)',
        CurrencyType.gbp => 'British Pound (GBP)',
        CurrencyType.aed => 'UAE Dirham (AED)',
        CurrencyType.other => 'Other',
      };

  String get symbol => switch (this) {
        CurrencyType.sar => 'ر.س',
        CurrencyType.usd => '\$',
        CurrencyType.eur => '€',
        CurrencyType.gbp => '£',
        CurrencyType.aed => 'د.إ',
        CurrencyType.other => '',
      };
}
