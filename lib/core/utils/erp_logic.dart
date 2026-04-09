import 'package:supermarket/data/datasources/local/app_database.dart';

class ErpLogic {
  /// يحسب القيم المالية لفاتورة بناءً على العناصر المضافة.
  /// تعتمد الحسابات على: (الكمية × السعر) - الخصم + الضريبة.
  static Map<String, double> calculateInvoiceTotals({
    required List<dynamic>
    items, // List of SaleItems or PurchaseItems companions/entities
    double globalDiscount = 0.0,
  }) {
    double subtotal = 0.0;
    double totalTax = 0.0;

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

    double total = (subtotal - globalDiscount);

    return {'subtotal': subtotal, 'tax': totalTax, 'total': total};
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
