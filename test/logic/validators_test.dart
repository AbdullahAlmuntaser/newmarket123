import 'package:flutter_test/flutter_test.dart';

class SalesValidator {
  static String? validateQuantity(double? quantity) {
    if (quantity == null) {
      return 'الكمية مطلوبة';
    }
    if (quantity <= 0) {
      return 'الكمية يجب أن تكون أكبر من صفر';
    }
    if (quantity > 999999) {
      return 'الكمية كبيرة جداً';
    }
    return null;
  }

  static String? validatePrice(double? price) {
    if (price == null) {
      return 'السعر مطلوب';
    }
    if (price < 0) {
      return 'السعر لا يمكن أن يكون سالباً';
    }
    if (price > 999999999) {
      return 'السعر كبير جداً';
    }
    return null;
  }

  static String? validateCustomer(String? customerId, bool isCredit) {
    if (isCredit && (customerId == null || customerId.isEmpty)) {
      return 'العميل مطلوب للمبيعات الآجلة';
    }
    return null;
  }

  static String? validateSaleItem({
    required String productId,
    required double quantity,
    required double price,
  }) {
    if (productId.isEmpty) {
      return 'المنتج مطلوب';
    }
    final qtyError = validateQuantity(quantity);
    if (qtyError != null) return qtyError;
    final priceError = validatePrice(price);
    if (priceError != null) return priceError;
    return null;
  }

  static List<String> validateSale({
    required List<Map<String, dynamic>> items,
    required double total,
    required bool isCredit,
    String? customerId,
  }) {
    final errors = <String>[];

    if (items.isEmpty) {
      errors.add('يجب إضافة صنف واحد على الأقل');
    }

    final customerError = validateCustomer(customerId, isCredit);
    if (customerError != null) {
      errors.add(customerError);
    }

    if (total <= 0) {
      errors.add('إجمالي الفاتورة يجب أن يكون أكبر من صفر');
    }

    return errors;
  }
}

class PurchaseValidator {
  static String? validateSupplier(String? supplierId, bool isCredit) {
    if (isCredit && (supplierId == null || supplierId.isEmpty)) {
      return 'المورد مطلوب للمشتريات الآجلة';
    }
    return null;
  }

  static String? validatePurchaseItem({
    required String productId,
    required double quantity,
    required double price,
  }) {
    if (productId.isEmpty) {
      return 'المنتج مطلوب';
    }
    if (quantity <= 0) {
      return 'الكمية يجب أن تكون أكبر من صفر';
    }
    if (price < 0) {
      return 'السعر لا يمكن أن يكون سالباً';
    }
    return null;
  }
}

class InventoryValidator {
  static String? validateStock(double currentStock, double deductQty) {
    if (deductQty <= 0) {
      return 'الكمية للخصم يجب أن تكون أكبر من صفر';
    }
    if (deductQty > currentStock) {
      return 'الكمية المتوفرة ($currentStock) غير كافية لخصم ($deductQty)';
    }
    return null;
  }

  static String? validateBatchQuantity(double quantity) {
    if (quantity < 0) {
      return 'الكمية لا يمكن أن تكون سالبة';
    }
    return null;
  }
}

class AccountingValidator {
  static String? validateAccountCode(String? code) {
    if (code == null || code.isEmpty) {
      return 'رمز الحساب مطلوب';
    }
    if (code.length < 4) {
      return 'رمز الحساب يجب أن يكون 4 أرقام على الأقل';
    }
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      return 'رمز الحساب يجب أن يحتوي على أرقام فقط';
    }
    return null;
  }

  static String? validateJournalEntry({
    required double totalDebit,
    required double totalCredit,
  }) {
    if ((totalDebit - totalCredit).abs() > 0.01) {
      return 'إجمالي المدين يجب أن يساوي إجمالي الدائن';
    }
    return null;
  }

  static String? validatePeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (endDate.isBefore(startDate)) {
      return 'تاريخ البداية يجب أن يكون قبل تاريخ النهاية';
    }
    if (startDate.isAfter(DateTime.now())) {
      return 'لا يمكن إنشاء فترة محاسبية في المستقبل';
    }
    return null;
  }
}

void main() {
  group('SalesValidator', () {
    group('validateQuantity', () {
      test('returns error for null quantity', () {
        expect(SalesValidator.validateQuantity(null), isNotNull);
      });

      test('returns error for zero quantity', () {
        expect(SalesValidator.validateQuantity(0), isNotNull);
      });

      test('returns error for negative quantity', () {
        expect(SalesValidator.validateQuantity(-5), isNotNull);
      });

      test('returns null for valid quantity', () {
        expect(SalesValidator.validateQuantity(10), isNull);
      });

      test('returns error for very large quantity', () {
        expect(SalesValidator.validateQuantity(9999999), isNotNull);
      });
    });

    group('validatePrice', () {
      test('returns error for null price', () {
        expect(SalesValidator.validatePrice(null), isNotNull);
      });

      test('returns null for zero price (free items)', () {
        expect(SalesValidator.validatePrice(0), isNull);
      });

      test('returns error for negative price', () {
        expect(SalesValidator.validatePrice(-10), isNotNull);
      });

      test('returns null for valid price', () {
        expect(SalesValidator.validatePrice(100), isNull);
      });
    });

    group('validateCustomer', () {
      test('returns error for credit sale without customer', () {
        expect(SalesValidator.validateCustomer(null, true), isNotNull);
      });

      test('returns error for credit sale with empty customer', () {
        expect(SalesValidator.validateCustomer('', true), isNotNull);
      });

      test('returns null for cash sale without customer', () {
        expect(SalesValidator.validateCustomer(null, false), isNull);
      });

      test('returns null for credit sale with customer', () {
        expect(SalesValidator.validateCustomer('cust-1', true), isNull);
      });
    });

    group('validateSaleItem', () {
      test('returns error for empty product', () {
        expect(
          SalesValidator.validateSaleItem(
            productId: '',
            quantity: 10,
            price: 100,
          ),
          isNotNull,
        );
      });

      test('returns null for valid item', () {
        expect(
          SalesValidator.validateSaleItem(
            productId: 'prod-1',
            quantity: 10,
            price: 100,
          ),
          isNull,
        );
      });
    });

    group('validateSale', () {
      test('returns error for empty items', () {
        final errors = SalesValidator.validateSale(
          items: [],
          total: 100,
          isCredit: false,
        );
        expect(errors.isNotEmpty, isTrue);
      });

      test('returns error for credit sale without customer', () {
        final errors = SalesValidator.validateSale(
          items: [{'productId': 'p1', 'quantity': 1, 'price': 10}],
          total: 10,
          isCredit: true,
          customerId: null,
        );
        expect(errors.any((e) => e.contains('العميل')), isTrue);
      });

      test('returns empty list for valid sale', () {
        final errors = SalesValidator.validateSale(
          items: [
            {'productId': 'prod-1', 'quantity': 1, 'price': 10}
          ],
          total: 10,
          isCredit: false,
        );
        expect(errors.isEmpty, isTrue);
      });
    });
  });

  group('PurchaseValidator', () {
    group('validateSupplier', () {
      test('returns error for credit purchase without supplier', () {
        expect(PurchaseValidator.validateSupplier(null, true), isNotNull);
      });

      test('returns null for cash purchase without supplier', () {
        expect(PurchaseValidator.validateSupplier(null, false), isNull);
      });
    });

    group('validatePurchaseItem', () {
      test('returns error for empty product', () {
        expect(
          PurchaseValidator.validatePurchaseItem(
            productId: '',
            quantity: 10,
            price: 100,
          ),
          isNotNull,
        );
      });

      test('returns null for valid item', () {
        expect(
          PurchaseValidator.validatePurchaseItem(
            productId: 'prod-1',
            quantity: 10,
            price: 100,
          ),
          isNull,
        );
      });
    });
  });

  group('InventoryValidator', () {
    group('validateStock', () {
      test('returns error for negative deduct quantity', () {
        expect(InventoryValidator.validateStock(100, -5), isNotNull);
      });

      test('returns error when deduct exceeds available', () {
        expect(InventoryValidator.validateStock(50, 100), isNotNull);
      });

      test('returns null for valid deduction', () {
        expect(InventoryValidator.validateStock(100, 50), isNull);
      });
    });
  });

  group('AccountingValidator', () {
    group('validateAccountCode', () {
      test('returns error for empty code', () {
        expect(AccountingValidator.validateAccountCode(''), isNotNull);
      });

      test('returns error for short code', () {
        expect(AccountingValidator.validateAccountCode('123'), isNotNull);
      });

      test('returns error for non-numeric code', () {
        expect(AccountingValidator.validateAccountCode('123A'), isNotNull);
      });

      test('returns null for valid numeric code', () {
        expect(AccountingValidator.validateAccountCode('1010'), isNull);
      });
    });

    group('validateJournalEntry', () {
      test('returns null when debits equal credits', () {
        expect(
          AccountingValidator.validateJournalEntry(
            totalDebit: 100,
            totalCredit: 100,
          ),
          isNull,
        );
      });

      test('returns error when debits do not equal credits', () {
        expect(
          AccountingValidator.validateJournalEntry(
            totalDebit: 100,
            totalCredit: 90,
          ),
          isNotNull,
        );
      });

      test('allows small rounding differences', () {
        expect(
          AccountingValidator.validateJournalEntry(
            totalDebit: 100.005,
            totalCredit: 100.0,
          ),
          isNull,
        );
      });
    });

    group('validatePeriod', () {
      test('returns error when end date before start date', () {
        final now = DateTime.now();
        expect(
          AccountingValidator.validatePeriod(
            startDate: now,
            endDate: now.subtract(const Duration(days: 1)),
          ),
          isNotNull,
        );
      });

      test('returns null for valid period', () {
        final now = DateTime.now();
        expect(
          AccountingValidator.validatePeriod(
            startDate: now.subtract(const Duration(days: 30)),
            endDate: now,
          ),
          isNull,
        );
      });
    });
  });
}
