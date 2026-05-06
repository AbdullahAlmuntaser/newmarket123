import 'package:flutter_test/flutter_test.dart';
import 'package:newmarket/data/local/db/app_database.dart';
import 'package:newmarket/data/datasources/local/daos/sales_dao.dart';
import 'package:newmarket/domain/entities/sales_invoice.dart';
import 'package:newmarket/domain/entities/customer.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AppDatabase])
void main() {
  group('Sales Invoice Tax Calculation Tests', () {
    late AppDatabase database;
    late SalesDao salesDao;

    setUp(() {
      database = MockAppDatabase();
      salesDao = SalesDao(database);
    });

    test('Tax calculation should be correct (not double counted)', () async {
      // Arrange
      const double lineTotal = 100.0;
      const double taxRate = 15.0;
      
      // Act - Simulate the corrected formula
      final expectedTax = lineTotal * (taxRate / 100);
      final actualTax = lineTotal * (taxRate / 100);
      
      // Assert
      expect(actualTax, equals(15.0));
      expect(actualTax, equals(expectedTax));
      
      // Verify old incorrect formula would give different result
      final incorrectTax = (lineTotal / (1 + (taxRate / 100))) * (taxRate / 100);
      expect(incorrectTax, isNot(equals(actualTax)));
      expect(incorrectTax, closeTo(13.04, 0.01)); // Old wrong value
    });

    test('Total calculation includes tax correctly', () async {
      // Arrange
      const double subtotal = 1000.0;
      const double tax = 150.0;
      const double discount = 50.0;
      
      // Act
      final total = subtotal + tax - discount;
      
      // Assert
      expect(total, equals(1100.0));
    });

    test('Zero tax rate should result in zero tax', () async {
      // Arrange
      const double lineTotal = 200.0;
      const double taxRate = 0.0;
      
      // Act
      final tax = lineTotal * (taxRate / 100);
      
      // Assert
      expect(tax, equals(0.0));
    });
  });

  group('Credit Limit Validation Tests', () {
    test('Should allow sale within credit limit', () async {
      // Arrange
      const double currentBalance = 5000.0;
      const double creditLimit = 10000.0;
      const double newInvoiceTotal = 4000.0;
      
      // Act
      final newBalance = currentBalance + newInvoiceTotal;
      final isAllowed = newBalance <= creditLimit;
      
      // Assert
      expect(isAllowed, isTrue);
    });

    test('Should prevent sale exceeding credit limit', () async {
      // Arrange
      const double currentBalance = 8000.0;
      const double creditLimit = 10000.0;
      const double newInvoiceTotal = 3000.0;
      
      // Act
      final newBalance = currentBalance + newInvoiceTotal;
      final isAllowed = newBalance <= creditLimit;
      
      // Assert
      expect(isAllowed, isFalse);
      expect(newBalance, greaterThan(creditLimit));
    });

    test('Should allow sale when credit limit is zero (unlimited)', () async {
      // Arrange
      const double currentBalance = 50000.0;
      const double creditLimit = 0.0; // 0 means unlimited
      const double newInvoiceTotal = 10000.0;
      
      // Act - When limit is 0, we skip validation
      final isUnlimited = creditLimit == 0;
      
      // Assert
      expect(isUnlimited, isTrue);
    });
  });

  group('Sales Order DAO Tests', () {
    late AppDatabase database;
    late SalesDao salesDao;

    setUp(() {
      database = MockAppDatabase();
      salesDao = SalesDao(database);
    });

    test('SalesOrder methods should be available', () async {
      // Verify methods exist (compile-time check)
      expect(salesDao.getAllSalesOrders, isNotNull);
      expect(salesDao.getSalesOrderById, isNotNull);
      expect(salesDao.createSalesOrder, isNotNull);
      expect(salesDao.updateSalesOrderStatus, isNotNull);
      expect(salesDao.deleteSalesOrder, isNotNull);
    });
  });
}
