import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class InvoiceService {
  static Future<File> generateInvoice(
    BuildContext context, {
    required Sale sale,
    required List<SaleItemWithProduct> items,
    required String companyName,
    required String vatNumber,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(sale.createdAt);

    // ZATCA-compliant QR code
    final qrCodeData = _generateZatcaQrCode(
      companyName: companyName,
      vatNumber: vatNumber,
      invoiceDate: sale.createdAt,
      total: sale.total,
      tax: sale.tax,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(localizations.vatNumber(vatNumber)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: qrCodeData,
                    width: 80,
                    height: 80,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                localizations.simplifiedTaxInvoice,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(localizations.invoiceNumber(sale.id.substring(0, 8))),
              pw.Text(localizations.dateLabel(dateStr)),
              pw.Text(localizations.paymentMethod(sale.paymentMethod)),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          localizations.productLabel,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          localizations.quantityLabel,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          localizations.price,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          localizations.total,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    final subtotal = item.quantity * item.price;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.product.name),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.quantity.toString()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.price.toStringAsFixed(2)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(subtotal.toStringAsFixed(2)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${localizations.subtotal}: ${(sale.total - sale.tax).toStringAsFixed(2)}',
                      ),
                      pw.Text('${localizations.tax}: ${sale.tax.toStringAsFixed(2)}'),
                      pw.Text(
                        '${localizations.total}: ${sale.total.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  localizations.thankYou,
                  style: pw.TextStyle(fontSize: 14),
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/invoice_${sale.id}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static String _generateZatcaQrCode({
    required String companyName,
    required String vatNumber,
    required DateTime invoiceDate,
    required double total,
    required double tax,
  }) {
    final sellerName = _getTlv(1, companyName);
    final vatNumberTlv = _getTlv(2, vatNumber);
    final timestamp = _getTlv(3, DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(invoiceDate.toUtc()));
    final totalTlv = _getTlv(4, total.toStringAsFixed(2));
    final taxTlv = _getTlv(5, tax.toStringAsFixed(2));

    final qrData = utf8.encode(sellerName + vatNumberTlv + timestamp + totalTlv + taxTlv);
    return base64.encode(qrData);
  }

  static String _getTlv(int tag, String value) {
    final tagHex = tag.toRadixString(16).padLeft(2, '0');
    final lengthHex = value.length.toRadixString(16).padLeft(2, '0');
    final valueHex = utf8.encode(value).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return tagHex + lengthHex + valueHex;
  }
}

class SaleItemWithProduct {
  final Product product;
  final double quantity;
  final double price;

  SaleItemWithProduct({
    required this.product,
    required this.quantity,
    required this.price,
  });
}
