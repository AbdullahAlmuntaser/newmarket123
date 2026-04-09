import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class PrinterHelper {
  // Mocking bluetooth for now since the library is problematic
  static dynamic bluetooth;

  static Future<bool> isConnected() async {
    return false;
  }

  static Future<List<dynamic>> getAvailableDevices() async {
    return [];
  }

  static Future<void> connect(dynamic device) async {}

  static Future<void> disconnect() async {}

  static Future<void> printReceipt(
    Sale sale,
    List<SaleItem> items,
    List<Product> products, {
    String? customerName,
  }) async {
    // Printing disabled temporarily
  }

  // Fallback if needed
  static Future<List<int>> generateSaleReceipt(
    Sale sale,
    List<SaleItem> items,
    List<Product> products, {
    String? customerName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text(
      'SUPERMARKET SYSTEM',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.createdAt)}',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Sale ID: ${sale.id.substring(0, 8)}',
      styles: const PosStyles(align: PosAlign.center),
    );
    if (customerName != null) {
      bytes += generator.text(
        'Customer: $customerName',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Total', width: 2, styles: const PosStyles(bold: true)),
    ]);

    for (var item in items) {
      final product = products.firstWhere((p) => p.id == item.productId);
      bytes += generator.row([
        PosColumn(text: product.name, width: 6),
        PosColumn(text: item.quantity.toString(), width: 2),
        PosColumn(text: item.price.toString(), width: 2),
        PosColumn(
          text: (item.quantity * item.price).toStringAsFixed(2),
          width: 2,
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.text(
      'Subtotal: ${(sale.total + sale.discount - sale.tax).toStringAsFixed(2)}',
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      'Discount: ${sale.discount.toStringAsFixed(2)}',
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      'Tax: ${sale.tax.toStringAsFixed(2)}',
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      'TOTAL: ${sale.total.toStringAsFixed(2)}',
      styles: const PosStyles(
        align: PosAlign.right,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.hr();
    bytes += generator.text(
      'Thank you for shopping!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}
