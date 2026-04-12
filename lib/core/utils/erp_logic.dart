import 'dart:convert';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:intl/intl.dart';

class ErpLogic {
  /// يحسب القيم المالية لفاتورة بناءً على العناصر المضافة.
  /// تعتمد الحسابات على: (الكمية × السعر) - الخصم + الضريبة.
  static Map<String, double> calculateInvoiceTotals({
    required List<dynamic> items, 
    double globalDiscount = 0.0,
    double taxRate = 0.15, // 15% Standard VAT
  }) {
    double subtotal = 0.0;
    
    for (var item in items) {
      double quantity = 0.0;
      double price = 0.0;

      if (item is SaleItemsCompanion) {
        quantity = item.quantity.value;
        price = item.price.value;
      } else if (item is PurchaseItemsCompanion) {
        quantity = item.quantity.value;
        price = item.price.value;
      } else if (item is SaleItem) {
        quantity = item.quantity;
        price = item.price;
      } else if (item is PurchaseItem) {
        quantity = item.quantity;
        price = item.price;
      }

      subtotal += quantity * price;
    }

    double taxableAmount = subtotal - globalDiscount;
    double tax = taxableAmount * taxRate;
    double total = taxableAmount + tax;

    return {
      'subtotal': subtotal,
      'taxableAmount': taxableAmount,
      'tax': tax,
      'total': total,
    };
  }

  /// توليد كود QR متوافق مع هيئة الزكاة والضريبة (ZATCA) - المرحلة الأولى والثانية
  static String generateZatcaQRCode({
    required String sellerName,
    required String vatNumber,
    required DateTime timestamp,
    required double invoiceTotal,
    required double vatTotal,
  }) {
    // 1. Tag 1: Seller Name
    // 2. Tag 2: VAT Registration Number
    // 3. Tag 3: Timestamp
    // 4. Tag 4: Invoice Total (with VAT)
    // 5. Tag 5: VAT Total

    List<int> bytes = [];

    void addTag(int tag, String value) {
      List<int> valueBytes = utf8.encode(value);
      bytes.add(tag);
      bytes.add(valueBytes.length);
      bytes.addAll(valueBytes);
    }

    addTag(1, sellerName);
    addTag(2, vatNumber);
    addTag(3, DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(timestamp.toUtc()));
    addTag(4, invoiceTotal.toStringAsFixed(2));
    addTag(5, vatTotal.toStringAsFixed(2));

    return base64.encode(bytes);
  }

  /// التحقق من توفر المخزون قبل البيع
  static bool hasEnoughStock(
    Product product,
    double requestedQty,
    bool isCarton,
  ) {
    double actualQty = isCarton
        ? requestedQty * product.piecesPerCarton
        : requestedQty;
    return product.stock >= actualQty;
  }
}
