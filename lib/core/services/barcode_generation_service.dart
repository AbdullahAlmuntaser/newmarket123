import 'dart:io';
import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;

class BarcodeGenerationService {
  static String generateEAN13() {
    final random = const Uuid().v4().replaceAll('-', '').substring(0, 12);
    final digits = random.split('').map(int.parse).toList();

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += digits[i] * (i % 2 == 0 ? 1 : 3);
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    digits.add(checkDigit);

    return digits.join();
  }

  static String generateCode128() {
    return const Uuid().v4().replaceAll('-', '').substring(0, 12).toUpperCase();
  }

  static String generateQRData({
    required String productName,
    required String sku,
    required String barcode,
    double? price,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Product: $productName');
    buffer.writeln('SKU: $sku');
    buffer.writeln('Barcode: $barcode');
    if (price != null) {
      buffer.writeln('Price: $price');
    }
    return buffer.toString();
  }

  static Uint8List? generateBarcodeImage({
    required String data,
    required BarcodeType type,
    double width = 300,
    double height = 100,
  }) {
    try {
      final Barcode barcode;
      switch (type) {
        case BarcodeType.ean13:
          barcode = Barcode.ean13();
          break;
        case BarcodeType.code128:
          barcode = Barcode.code128();
          break;
        case BarcodeType.qrCode:
          barcode = Barcode.qrCode();
          break;
        default:
          barcode = Barcode.code128();
      }

      final svg = barcode.toSvg(
        data,
        width: width,
        height: height,
      );

      return Uint8List.fromList(svg.codeUnits);
    } catch (e) {
      return null;
    }
  }

  static File? generateBarcodeFile({
    required String data,
    required BarcodeType type,
    required String outputPath,
    double width = 300,
    double height = 100,
  }) {
    try {
      final bytes = generateBarcodeImage(
        data: data,
        type: type,
        width: width,
        height: height,
      );
      if (bytes == null) return null;
      final file = File(outputPath);
      file.writeAsBytesSync(bytes);
      return file;
    } catch (e) {
      return null;
    }
  }

  static String generateBarcodeSvg({
    required String data,
    required BarcodeType type,
    double width = 300,
    double height = 100,
  }) {
    try {
      final Barcode barcode;
      switch (type) {
        case BarcodeType.ean13:
          barcode = Barcode.ean13();
          break;
        case BarcodeType.code128:
          barcode = Barcode.code128();
          break;
        case BarcodeType.qrCode:
          barcode = Barcode.qrCode();
          break;
        default:
          barcode = Barcode.code128();
      }

      return barcode.toSvg(
        data,
        width: width,
        height: height,
      );
    } catch (e) {
      return '';
    }
  }

  static bool isValidEAN13(String code) {
    if (code.length != 13) return false;
    if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;

    final digits = code.split('').map(int.parse).toList();
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += digits[i] * (i % 2 == 0 ? 1 : 3);
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == digits[12];
  }

  static String autoGenerateBarcode({BarcodeType type = BarcodeType.code128}) {
    switch (type) {
      case BarcodeType.ean13:
        return generateEAN13();
      case BarcodeType.code128:
        return generateCode128();
      default:
        return generateCode128();
    }
  }

  static Future<void> batchGenerateBarcodes({
    required List<Map<String, dynamic>> products,
    BarcodeType type = BarcodeType.code128,
  }) async {
    for (final product in products) {
      final String? existingBarcode = product['barcode'];
      if (existingBarcode == null || existingBarcode.isEmpty) {
        autoGenerateBarcode(type: type);
      }
    }
  }
}

enum BarcodeType {
  ean13,
  code128,
  qrCode,
}

class BarcodeLabel {
  final String productName;
  final String sku;
  final String barcode;
  final BarcodeType type;
  final double? price;
  final int quantity;

  BarcodeLabel({
    required this.productName,
    required this.sku,
    required this.barcode,
    this.type = BarcodeType.code128,
    this.price,
    this.quantity = 1,
  });
}
