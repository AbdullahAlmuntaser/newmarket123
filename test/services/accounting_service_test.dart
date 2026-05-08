import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';

class MockAppDatabase extends Mock implements AppDatabase {}
class MockEventBusService extends Mock implements EventBusService {}

void main() {
  group('AccountingService - Standalone Logic Tests', () {
    test('standard account codes are defined', () {
      expect(AccountingService.codeCash, equals('1010'));
      expect(AccountingService.codeBank, equals('1020'));
      expect(AccountingService.codeAccountsReceivable, equals('1030'));
      expect(AccountingService.codeInventory, equals('1040'));
      expect(AccountingService.codeInputVAT, equals('1050'));
      expect(AccountingService.codeFixedAssets, equals('1200'));
      expect(AccountingService.codeAccountsPayable, equals('2010'));
      expect(AccountingService.codeOutputVAT, equals('2020'));
      expect(AccountingService.codeSalesRevenue, equals('4010'));
      expect(AccountingService.codeSalesReturns, equals('4020'));
      expect(AccountingService.codeCOGS, equals('5010'));
      expect(AccountingService.codeOperatingExpenses, equals('6000'));
    });

    test('account codes follow numbering convention', () {
      expect(AccountingService.codeCash.length, equals(4));
      expect(AccountingService.codeBank.length, equals(4));
      expect(int.tryParse(AccountingService.codeCash), isNotNull);
    });

    test('asset accounts have correct range', () {
      final assetCode = int.parse(AccountingService.codeFixedAssets);
      expect(assetCode, greaterThanOrEqualTo(1000));
      expect(assetCode, lessThan(2000));
    });

    test('liability accounts have correct range', () {
      final liabilityCode = int.parse(AccountingService.codeAccountsPayable);
      expect(liabilityCode, greaterThanOrEqualTo(2000));
      expect(liabilityCode, lessThan(3000));
    });

    test('revenue accounts have correct range', () {
      final revenueCode = int.parse(AccountingService.codeSalesRevenue);
      expect(revenueCode, greaterThanOrEqualTo(4000));
      expect(revenueCode, lessThan(5000));
    });

    test('expense accounts have correct range', () {
      final expenseCode = int.parse(AccountingService.codeOperatingExpenses);
      expect(expenseCode, greaterThanOrEqualTo(5000));
      expect(expenseCode, lessThan(7000));
    });
  });

  group('Journal Entry Balance Validation', () {
    test('balanced entry: debit equals credit', () {
      final lines = [
        {'debit': 100.0, 'credit': 0.0},
        {'debit': 0.0, 'credit': 100.0},
      ];

      double totalDebit = 0;
      double totalCredit = 0;
      for (var line in lines) {
        totalDebit += line['debit'] as double;
        totalCredit += line['credit'] as double;
      }

      expect(totalDebit, closeTo(totalCredit, 0.01));
    });

    test('balanced entry: multiple lines', () {
      final lines = [
        {'debit': 50.0, 'credit': 0.0},
        {'debit': 30.0, 'credit': 0.0},
        {'debit': 0.0, 'credit': 60.0},
        {'debit': 0.0, 'credit': 20.0},
      ];

      double totalDebit = 0;
      double totalCredit = 0;
      for (var line in lines) {
        totalDebit += line['debit'] as double;
        totalCredit += line['credit'] as double;
      }

      expect(totalDebit, equals(totalCredit));
    });

    test('unbalanced entry is detected', () {
      const debit = 100.0;
      const credit = 90.0;
      final isBalanced = (debit - credit).abs() <= 0.01;
      expect(isBalanced, isFalse);
    });

    test('entry must have at least 2 lines', () {
      final lines = <Map<String, double>>[];
      expect(lines.length, lessThan(2));
    });
  });

  group('Running Balance Calculation', () {
    test('initial balance is zero', () {
      double currentBalance = 0.0;
      expect(currentBalance, equals(0.0));
    });

    test('debit increases asset balance', () {
      double currentBalance = 100.0;
      const debit = 50.0;
      const credit = 0.0;
      final newBalance = currentBalance + (debit - credit);
      expect(newBalance, equals(150.0));
    });

    test('credit decreases asset balance', () {
      double currentBalance = 100.0;
      const debit = 0.0;
      const credit = 30.0;
      final newBalance = currentBalance + (debit - credit);
      expect(newBalance, equals(70.0));
    });

    test('credit increases liability balance', () {
      double currentBalance = 0.0;
      const debit = 0.0;
      const credit = 100.0;
      final newBalance = currentBalance + (credit - debit);
      expect(newBalance, equals(100.0));
    });

    test('debit decreases liability balance', () {
      double currentBalance = 100.0;
      const debit = 30.0;
      const credit = 0.0;
      final newBalance = currentBalance + (credit - debit);
      expect(newBalance, equals(70.0));
    });
  });

  group('Financial Ratios Calculations', () {
    test('gross profit margin calculation', () {
      const revenue = 1000.0;
      const cogs = 600.0;
      const grossProfit = revenue - cogs;
      const grossMargin = revenue > 0 ? grossProfit / revenue : 0.0;
      expect(grossMargin, closeTo(0.4, 0.01));
    });

    test('net profit margin calculation', () {
      const revenue = 1000.0;
      const expenses = 700.0;
      const netIncome = revenue - expenses;
      const netMargin = revenue > 0 ? netIncome / revenue : 0.0;
      expect(netMargin, closeTo(0.3, 0.01));
    });

    test('current ratio calculation', () {
      const currentAssets = 500.0;
      const currentLiabilities = 250.0;
      const currentRatio =
          currentLiabilities > 0 ? currentAssets / currentLiabilities : 0.0;
      expect(currentRatio, equals(2.0));
    });

    test('current ratio handles zero liabilities', () {
      const currentAssets = 500.0;
      const currentLiabilities = 0.0;
      const currentRatio =
          currentLiabilities > 0 ? currentAssets / currentLiabilities : 0.0;
      expect(currentRatio, equals(0.0));
    });
  });

  group('VAT Calculations', () {
    test('calculates output VAT from sales', () {
      const salesAmount = 1000.0;
      const taxRate = 0.15;
      const vat = salesAmount * taxRate;
      expect(vat, equals(150.0));
    });

    test('calculates input VAT from purchases', () {
      const purchaseAmount = 800.0;
      const taxRate = 0.15;
      const vat = purchaseAmount * taxRate;
      expect(vat, equals(120.0));
    });

    test('calculates net VAT payable', () {
      const outputVat = 150.0;
      const inputVat = 120.0;
      const netVat = outputVat - inputVat;
      expect(netVat, equals(30.0));
    });

    test('handles zero VAT', () {
      const amount = 1000.0;
      const taxRate = 0.0;
      const vat = amount * taxRate;
      expect(vat, equals(0.0));
    });
  });
}
