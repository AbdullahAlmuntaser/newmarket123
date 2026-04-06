import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';

class PDFService {
  /// توليد فاتورة مبيعات بصيغة PDF
  static Future<Uint8List> generateSaleInvoice({
    required Sale sale,
    required List<SaleItem> items,
    required List<Product> products,
    String? customerName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SALE INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ID: ${sale.id.substring(0, 8)}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.createdAt)}'),
                      pw.Text('Customer: ${customerName ?? 'Walk-in Customer'}'),
                      pw.Text('Payment Method: ${sale.paymentMethod}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Product', 'Quantity', 'Price', 'Total'],
                data: items.map((item) {
                  final product = products.firstWhere((p) => p.id == item.productId);
                  return [
                    product.name,
                    item.quantity.toString(),
                    item.price.toStringAsFixed(2),
                    (item.quantity * item.price).toStringAsFixed(2),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${(sale.total + sale.discount - sale.tax).toStringAsFixed(2)}'),
                    pw.Text('Discount: ${sale.discount.toStringAsFixed(2)}'),
                    pw.Text('Tax: ${sale.tax.toStringAsFixed(2)}'),
                    pw.Divider(),
                    pw.Text('TOTAL: ${sale.total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              pw.Footer(
                margin: const pw.EdgeInsets.only(top: 50),
                trailing: pw.Text('Thank you for your business!'),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// توليد ميزانية عمومية بصيغة PDF
  static Future<Uint8List> generateBalanceSheetPDF(BalanceSheetData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('BALANCE SHEET', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('As of ${DateFormat('yyyy-MM-dd').format(data.date)}')),
              pw.SizedBox(height: 30),
              
              pw.Text('ASSETS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              ...data.assets.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text(item.account.name), pw.Text(item.balance.toStringAsFixed(2))],
              )),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Total Assets', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(data.totalAssets.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
              ),
              
              pw.SizedBox(height: 20),
              pw.Text('LIABILITIES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              ...data.liabilities.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text(item.account.name), pw.Text(item.balance.toStringAsFixed(2))],
              )),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Total Liabilities', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(data.totalLiabilities.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
              ),

              pw.SizedBox(height: 20),
              pw.Text('EQUITY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              ...data.equity.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text(item.account.name), pw.Text(item.balance.toStringAsFixed(2))],
              )),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Net Income', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)), pw.Text(data.netIncome.toStringAsFixed(2))],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Total Equity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(data.totalEquity.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
