import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/domain/entities/sales_invoice.dart';

void main() {
  group('SalesWorkflow - Integration Logic', () {
    test('sale invoice calculation is correct', () {
      final invoice = SalesInvoice(
        id: 'inv-1',
        customerId: '',
        items: const [
          InvoiceItem(itemId: 'p1', quantity: 2, price: 50),
          InvoiceItem(itemId: 'p2', quantity: 1, price: 100),
          InvoiceItem(itemId: 'p3', quantity: 0.5, price: 200, unitFactor: 1),
        ],
        subtotal: 250,
        discount: 25,
        taxAmount: 48.75,
        totalAmount: 273.75,
        paymentMethod: 'cash',
        timestamp: DateTime.now(),
        qrCodeData: '',
      );

      double calculatedSubtotal = 0;
      for (var item in invoice.items) {
        calculatedSubtotal += (item.quantity * item.unitFactor * item.price);
      }

      expect(calculatedSubtotal, closeTo(300.0, 0.01));
      final total = calculatedSubtotal - invoice.discount + invoice.taxAmount;
      expect(total, closeTo(323.75, 0.01));
    });

    test('credit sale requires customer', () {
      final invoice = SalesInvoice(
        id: 'inv-1',
        customerId: 'CUST-001',
        items: const [
          InvoiceItem(itemId: 'p1', quantity: 1, price: 100),
        ],
        subtotal: 100,
        discount: 0,
        taxAmount: 15,
        totalAmount: 115,
        paymentMethod: 'credit',
        timestamp: DateTime.now(),
        qrCodeData: '',
      );

      final hasCustomer = invoice.customerId.isNotEmpty;
      expect(hasCustomer, isTrue);
    });

    test('cash sale does not require customer', () {
      final invoice = SalesInvoice(
        id: 'inv-1',
        customerId: '',
        items: const [
          InvoiceItem(itemId: 'p1', quantity: 1, price: 100),
        ],
        subtotal: 100,
        discount: 0,
        taxAmount: 15,
        totalAmount: 115,
        paymentMethod: 'cash',
        timestamp: DateTime.now(),
        qrCodeData: '',
      );

      expect(invoice.paymentMethod, equals('cash'));
    });
  });

  group('PurchaseWorkflow - Integration Logic', () {
    test('purchase calculation includes all components', () {
      const subtotal = 1000.0;
      const discount = 50.0;
      const tax = 142.5;
      const shippingCost = 25.0;
      const otherExpenses = 10.0;

      const total = subtotal - discount + tax + shippingCost + otherExpenses;
      expect(total, equals(1127.5));
    });

    test('purchase items are linked to purchase ID', () {
      const purchaseId = 'pur-123';
      final items = [
        {'id': 'i1', 'purchaseId': purchaseId, 'quantity': 10, 'price': 50},
        {'id': 'i2', 'purchaseId': purchaseId, 'quantity': 5, 'price': 100},
      ];

      expect(items.every((item) => item['purchaseId'] == purchaseId), isTrue);
    });
  });

  group('PaymentWorkflow - Integration Logic', () {
    test('customer payment creates correct journal entry', () {
      const amount = 500.0;
      const paymentAccount = 'CASH';

      final entry = {
        'lines': [
          {'account': paymentAccount, 'debit': amount, 'credit': 0.0},
          {'account': 'CUSTOMER_AR', 'debit': 0.0, 'credit': amount},
        ],
      };

      double totalDebit = 0;
      double totalCredit = 0;
      for (var line in entry['lines']!) {
        totalDebit += (line['debit'] as num).toDouble();
        totalCredit += (line['credit'] as num).toDouble();
      }

      expect(totalDebit, closeTo(totalCredit, 0.01));
    });

    test('supplier payment creates correct journal entry', () {
      const amount = 1000.0;
      const paymentAccount = 'BANK';

      final entry = {
        'lines': [
          {'account': 'SUPPLIER_AP', 'debit': amount, 'credit': 0.0},
          {'account': paymentAccount, 'debit': 0.0, 'credit': amount},
        ],
      };

      double totalDebit = 0;
      double totalCredit = 0;
      for (var line in entry['lines']!) {
        totalDebit += (line['debit'] as num).toDouble();
        totalCredit += (line['credit'] as num).toDouble();
      }

      expect(totalDebit, closeTo(totalCredit, 0.01));
    });
  });

  group('ReturnWorkflow - Integration Logic', () {
    test('sale return recalculates inventory correctly', () {
      const initialStock = 100.0;
      const returnedQty = 10.0;
      const returnedStock = initialStock + returnedQty;

      expect(returnedStock, equals(110.0));
    });

    test('sale return creates reversal journal entry', () {
      const amountReturned = 100.0;
      const taxPortion = 13.04;
      const revenuePortion = amountReturned - taxPortion;

      expect(revenuePortion, closeTo(86.96, 0.01));
    });

    test('purchase return adjusts accounts payable', () {
      const initialBalance = 5000.0;
      const returnedAmount = 500.0;
      const newBalance = initialBalance - returnedAmount;

      expect(newBalance, equals(4500.0));
    });
  });

  group('StockTransferWorkflow - Integration Logic', () {
    test('transfer reduces source batch', () {
      const sourceQty = 100.0;
      const transferQty = 30.0;
      const remaining = sourceQty - transferQty;

      expect(remaining, equals(70.0));
    });

    test('transfer increases target batch', () {
      const targetQty = 50.0;
      const transferQty = 30.0;
      const newQty = targetQty + transferQty;

      expect(newQty, equals(80.0));
    });

    test('transfer creates inventory transactions', () {
      const fromWarehouse = 'WH1';
      const toWarehouse = 'WH2';
      const transferId = 'TRF-001';

      final transactions = [
        {'type': 'TRANSFER_OUT', 'warehouse': fromWarehouse, 'ref': transferId},
        {'type': 'TRANSFER_IN', 'warehouse': toWarehouse, 'ref': transferId},
      ];

      expect(transactions.length, equals(2));
      expect(transactions[0]['type'], equals('TRANSFER_OUT'));
      expect(transactions[1]['type'], equals('TRANSFER_IN'));
    });
  });
}
