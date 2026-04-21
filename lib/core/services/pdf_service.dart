import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/qr_code_generator.dart';

class PdfInvoiceService {
  Future<void> printInvoice({
    required String invoiceId,
    required String customerName,
    required String totalAmount,
    required String vatAmount,
    required List<Map<String, String>> items,
  }) async {
    final pdf = pw.Document();

    // Generate QR Data
    final qrData = QrTlvGenerator.generate(
      sellerName: "نظام الشركة",
      vatNumber: "300000000000003",
      timestamp: DateTime.now().toIso8601String(),
      totalAmount: totalAmount,
      vatAmount: vatAmount,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "فاتورة ضريبية",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),
                pw.Text("رقم الفاتورة: $invoiceId"),
                pw.Text("العميل: $customerName"),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ["الصنف", "السعر"],
                  data: items.map((i) => [i['name']!, i['price']!]).toList(),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text("الإجمالي: $totalAmount"),
                        pw.Text("الضريبة: $vatAmount"),
                      ],
                    ),
                    pw.BarcodeWidget(
                      data: base64Encode(qrData),
                      barcode: pw.Barcode.qrCode(),
                      width: 80,
                      height: 80,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
