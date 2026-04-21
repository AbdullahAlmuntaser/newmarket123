import 'dart:convert';
import 'dart:typed_data';

/// Helper to generate QR code data in ZATCA-compliant TLV format
class QrTlvGenerator {
  static Uint8List generate({
    required String sellerName,
    required String vatNumber,
    required String timestamp,
    required String totalAmount,
    required String vatAmount,
  }) {
    final bytes = <int>[];
    _addTlv(bytes, 1, sellerName);
    _addTlv(bytes, 2, vatNumber);
    _addTlv(bytes, 3, timestamp);
    _addTlv(bytes, 4, totalAmount);
    _addTlv(bytes, 5, vatAmount);
    return Uint8List.fromList(bytes);
  }

  static void _addTlv(List<int> bytes, int tag, String value) {
    final utf8Val = utf8.encode(value);
    bytes.add(tag);
    bytes.add(utf8Val.length);
    bytes.addAll(utf8Val);
  }
}
