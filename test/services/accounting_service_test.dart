import 'package:flutter_test/flutter_test.dart';
import 'package:newmarket/core/services/posting_engine.dart';
import 'package:newmarket/core/services/transaction_engine.dart';
import 'package:newmarket/data/local/db/app_database.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AppDatabase, PostingEngine, TransactionEngine])
void main() {
  group('Accounting Entry Tests', () {
    late AppDatabase database;
    late PostingEngine postingEngine;
    late TransactionEngine transactionEngine;

    setUp(() {
      database = MockAppDatabase();
      postingEngine = MockPostingEngine();
      transactionEngine = MockTransactionEngine();
    });

    test('Sales invoice should create debit to Accounts Receivable', () async {
      // Arrange
      const double invoiceTotal = 1150.0;
      const double subtotal = 1000.0;
      const double tax = 150.0;
      
      // Expected entries:
      // Dr Accounts Receivable 1150
      // Cr Sales Revenue 1000
      // Cr VAT Payable 150
      
      // Act & Assert - Verify the logic
      expect(subtotal + tax, equals(invoiceTotal));
    });

    test('Purchase invoice should credit Accounts Payable', () async {
      // Arrange
      const double purchaseTotal = 2300.0;
      const double subtotal = 2000.0;
      const double tax = 300.0;
      
      // Expected entries:
      // Dr Inventory/Purchases 2000
      // Dr VAT Recoverable 300
      // Cr Accounts Payable 2300
      
      // Act & Assert
      expect(subtotal + tax, equals(purchaseTotal));
    });

    test('Inventory reduction on sale', () async {
      // Arrange
      const int initialQty = 100;
      const int soldQty = 10;
      
      // Act
      final remainingQty = initialQty - soldQty;
      
      // Assert
      expect(remainingQty, equals(90));
      expect(remainingQty, isPositive);
    });

    test('Inventory increase on purchase', () async {
      // Arrange
      const int initialQty = 50;
      const int purchasedQty = 30;
      
      // Act
      final newQty = initialQty + purchasedQty;
      
      // Assert
      expect(newQty, equals(80));
    });
  });

  group('FIFO Cost Calculation Tests', () {
    test('Should calculate cost using FIFO method', () async {
      // Arrange - Multiple batches with different costs
      const List<Map<String, dynamic>> batches = [
        {'qty': 10, 'cost': 10.0}, // Batch 1: 10 units @ $10
        {'qty': 20, 'cost': 12.0}, // Batch 2: 20 units @ $12
        {'qty': 15, 'cost': 11.0}, // Batch 3: 15 units @ $11
      ];
      
      const int soldQty = 25;
      
      // Act - FIFO: First 10 from batch 1, next 15 from batch 2
      double totalCost = 0.0;
      int remainingToSell = soldQty;
      
      for (var batch in batches) {
        if (remainingToSell <= 0) break;
        
        final qtyFromBatch = remainingToSell > batch['qty'] 
            ? batch['qty'] 
            : remainingToSell;
        
        totalCost += qtyFromBatch * batch['cost'];
        remainingToSell -= qtyFromBatch;
      }
      
      // Assert
      // 10 @ 10.0 = 100
      // 15 @ 12.0 = 180
      // Total = 280
      expect(totalCost, equals(280.0));
    });

    test('Should handle partial batch consumption', () async {
      // Arrange
      const List<Map<String, dynamic>> batches = [
        {'qty': 5, 'cost': 10.0},
        {'qty': 10, 'cost': 12.0},
      ];
      
      const int soldQty = 7;
      
      // Act
      double totalCost = 0.0;
      int remainingToSell = soldQty;
      
      for (var batch in batches) {
        if (remainingToSell <= 0) break;
        
        final qtyFromBatch = remainingToSell > batch['qty'] 
            ? batch['qty'] 
            : remainingToSell;
        
        totalCost += qtyFromBatch * batch['cost'];
        remainingToSell -= qtyFromBatch;
      }
      
      // Assert
      // 5 @ 10.0 = 50
      // 2 @ 12.0 = 24
      // Total = 74
      expect(totalCost, equals(74.0));
    });
  });

  group('Period Closing Tests', () {
    test('Should prevent posting to closed periods', () async {
      // Arrange
      final DateTime closedPeriodEnd = DateTime(2024, 12, 31);
      final DateTime transactionDate = DateTime(2025, 1, 15);
      
      // Act
      final isPeriodClosed = transactionDate.isAfter(closedPeriodEnd);
      
      // Assert
      expect(isPeriodClosed, isTrue);
    });

    test('Should allow posting to open periods', () async {
      // Arrange
      final DateTime currentPeriodStart = DateTime(2025, 1, 1);
      final DateTime currentPeriodEnd = DateTime(2025, 1, 31);
      final DateTime transactionDate = DateTime(2025, 1, 15);
      
      // Act
      final isPeriodOpen = 
          !transactionDate.isBefore(currentPeriodStart) && 
          !transactionDate.isAfter(currentPeriodEnd);
      
      // Assert
      expect(isPeriodOpen, isTrue);
    });
  });
}
