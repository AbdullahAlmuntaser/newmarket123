import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/constants/app_enums.dart';

void main() {
  group('DocumentStatus', () {
    test('has correct values', () {
      expect(DocumentStatus.draft.index, equals(0));
      expect(DocumentStatus.posted.index, equals(1));
      expect(DocumentStatus.received.index, equals(2));
      expect(DocumentStatus.cancelled.index, equals(3));
    });

    test('can be compared', () {
      expect(DocumentStatus.draft, equals(DocumentStatus.draft));
      expect(DocumentStatus.draft, isNot(equals(DocumentStatus.posted)));
    });

    test('values are in expected order', () {
      expect(DocumentStatus.values.length, equals(7));
    });

    test('display names are correct', () {
      expect(DocumentStatus.draft.displayName, equals('Draft'));
      expect(DocumentStatus.posted.displayName, equals('Posted'));
    });
  });

  group('PaymentMethod', () {
    test('has correct values', () {
      expect(PaymentMethod.values.length, equals(3));
      expect(PaymentMethod.cash.index, equals(0));
      expect(PaymentMethod.bank.index, equals(1));
      expect(PaymentMethod.check.index, equals(2));
    });

    test('has display name support', () {
      expect(PaymentMethod.cash.name, equals('Cash'));
      expect(PaymentMethod.bank.name, equals('Card'));
      expect(PaymentMethod.check.name, equals('Check'));
    });
  });

  group('TransactionType', () {
    test('has correct values', () {
      expect(TransactionType.values.length, greaterThan(0));
    });

    test('sale type is available', () {
      expect(TransactionType.sale.index, greaterThanOrEqualTo(0));
    });

    test('purchase type is available', () {
      expect(TransactionType.purchase.index, greaterThanOrEqualTo(0));
    });
  });

  group('AccountType', () {
    test('has all required types', () {
      expect(AccountType.values.length, equals(5));
      expect(AccountType.asset, isNotNull);
      expect(AccountType.liability, isNotNull);
      expect(AccountType.equity, isNotNull);
      expect(AccountType.revenue, isNotNull);
      expect(AccountType.expense, isNotNull);
    });
  });
}
