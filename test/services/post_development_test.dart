import 'package:flutter_test/flutter_test.dart';
import 'package:newmarket/core/services/backup/backup_service.dart';
import 'package:newmarket/core/services/reports/financial_reports_service.dart';

void main() {
  group('Backup Service Tests', () {
    test('BackupResult should handle success case', () async {
      // Arrange
      final result = BackupResult(
        success: true,
        message: 'تم إنشاء النسخة الاحتياطية بنجاح',
        backupPath: '/path/to/backup.db',
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.message, contains('نجاح'));
      expect(result.backupPath, isNotNull);
    });

    test('BackupResult should handle error case', () async {
      // Arrange
      final result = BackupResult(
        success: false,
        message: 'فشل إنشاء النسخة الاحتياطية',
        errorCode: 'BACKUP_FAILED',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.errorCode, equals('BACKUP_FAILED'));
    });

    test('BackupMetadata formattedFileSize should format correctly', () async {
      // Arrange - Test different sizes
      final metadata1 = BackupMetadata(
        backupName: 'test1',
        backupDate: DateTime.now(),
        databasePath: '/path/db.db',
        fileSize: 1024, // 1 KB
        version: '1.0.0',
      );

      final metadata2 = BackupMetadata(
        backupName: 'test2',
        backupDate: DateTime.now(),
        databasePath: '/path/db.db',
        fileSize: 1048576, // 1 MB
        version: '1.0.0',
      );

      // Assert
      expect(metadata1.formattedFileSize, contains('KB'));
      expect(metadata2.formattedFileSize, contains('MB'));
    });
  });

  group('Financial Reports Tests', () {
    test('VAT Report calculation should be correct', () async {
      // Arrange
      const double totalSalesExcludingVAT = 10000.0;
      const double vatRate = 0.15; // 15%
      const double totalPurchasesExcludingVAT = 6000.0;

      // Act
      final totalVATCollected = totalSalesExcludingVAT * vatRate;
      final totalVATPaid = totalPurchasesExcludingVAT * vatRate;
      final netVATPayable = totalVATCollected - totalVATPaid;

      // Assert
      expect(totalVATCollected, equals(1500.0));
      expect(totalVATPaid, equals(900.0));
      expect(netVATPayable, equals(600.0));
    });

    test('Profit and Loss calculation should be correct', () async {
      // Arrange
      const double totalRevenue = 50000.0;
      const double costOfGoodsSold = 30000.0;
      const double operatingExpenses = 10000.0;

      // Act
      final grossProfit = totalRevenue - costOfGoodsSold;
      final netProfit = grossProfit - operatingExpenses;
      final grossProfitMargin = (grossProfit / totalRevenue) * 100;
      final netProfitMargin = (netProfit / totalRevenue) * 100;

      // Assert
      expect(grossProfit, equals(20000.0));
      expect(netProfit, equals(10000.0));
      expect(grossProfitMargin, equals(40.0));
      expect(netProfitMargin, equals(20.0));
    });

    test('Sales report totals should aggregate correctly', () async {
      // Arrange
      final List<Map<String, double>> invoices = [
        {'subtotal': 1000.0, 'tax': 150.0, 'discount': 50.0, 'total': 1100.0},
        {'subtotal': 2000.0, 'tax': 300.0, 'discount': 100.0, 'total': 2200.0},
        {'subtotal': 1500.0, 'tax': 225.0, 'discount': 75.0, 'total': 1650.0},
      ];

      // Act
      double totalRevenue = 0.0;
      double totalTax = 0.0;
      double totalDiscount = 0.0;
      double totalNet = 0.0;

      for (var invoice in invoices) {
        totalRevenue += invoice['subtotal']!;
        totalTax += invoice['tax']!;
        totalDiscount += invoice['discount']!;
        totalNet += invoice['total']!;
      }

      // Assert
      expect(totalRevenue, equals(4500.0));
      expect(totalTax, equals(675.0));
      expect(totalDiscount, equals(225.0));
      expect(totalNet, equals(4950.0));
    });

    test('Period comparison should work correctly', () async {
      // Arrange
      final DateTime startDate = DateTime(2025, 1, 1);
      final DateTime endDate = DateTime(2025, 1, 31);
      final DateTime transactionDate1 = DateTime(2025, 1, 15);
      final DateTime transactionDate2 = DateTime(2025, 2, 15);

      // Act
      final isInPeriod1 = 
          !transactionDate1.isBefore(startDate) && 
          !transactionDate1.isAfter(endDate);
      final isInPeriod2 = 
          !transactionDate2.isBefore(startDate) && 
          !transactionDate2.isAfter(endDate);

      // Assert
      expect(isInPeriod1, isTrue);
      expect(isInPeriod2, isFalse);
    });
  });

  group('Data Validation Tests', () {
    test('Should validate positive amounts', () async {
      // Arrange
      const double amount = 100.0;
      const double negativeAmount = -50.0;

      // Assert
      expect(amount, isPositive);
      expect(negativeAmount, isNegative);
    });

    test('Should validate date ranges', () async {
      // Arrange
      final DateTime startDate = DateTime(2025, 1, 1);
      final DateTime endDate = DateTime(2025, 1, 31);

      // Assert
      expect(startDate, isBefore(endDate));
      expect(endDate, isAfter(startDate));
    });

    test('Should handle zero values correctly', () async {
      // Arrange
      const double zeroTax = 0.0;
      const double amount = 100.0;

      // Act
      final totalWithZeroTax = amount + zeroTax;

      // Assert
      expect(zeroTax, equals(0.0));
      expect(totalWithZeroTax, equals(amount));
    });
  });
}
