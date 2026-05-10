import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:intl/intl.dart' as intl;

class StatementPrintingService {
  final AppDatabase db;

  StatementPrintingService(this.db);

  Future<void> printAccountStatement({
    required GLAccount account,
    required List<AccountTransaction> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(account, startDate, endDate),
            pw.SizedBox(height: 20),
            _buildTransactionTable(transactions),
            pw.SizedBox(height: 20),
            _buildFooter(transactions),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildHeader(GLAccount account, DateTime start, DateTime end) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('كشف حساب', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('Account Statement', style: const pw.TextStyle(fontSize: 18)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('اسم الحساب: ${account.name}'),
            pw.Text('كود الحساب: ${account.code}'),
          ],
        ),
        pw.Text('الفترة: ${intl.DateFormat('yyyy-MM-dd').format(start)} - ${intl.DateFormat('yyyy-MM-dd').format(end)}'),
      ],
    );
  }

  pw.Widget _buildTransactionTable(List<AccountTransaction> transactions) {
    final headers = ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: transactions.map((t) {
        return [
          intl.DateFormat('yyyy-MM-dd').format(t.date),
          t.type,
          t.debit.toStringAsFixed(2),
          t.credit.toStringAsFixed(2),
          t.runningBalance.toStringAsFixed(2),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerRight,
    );
  }

  pw.Widget _buildFooter(List<AccountTransaction> transactions) {
    double totalDebit = transactions.fold(0, (sum, t) => sum + t.debit);
    double totalCredit = transactions.fold(0, (sum, t) => sum + t.credit);
    double finalBalance = transactions.isNotEmpty ? transactions.last.runningBalance : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('إجمالي المدين: ${totalDebit.toStringAsFixed(2)}'),
        pw.Text('إجمالي الدائن: ${totalCredit.toStringAsFixed(2)}'),
        pw.Text('الرصيد النهائي: ${finalBalance.toStringAsFixed(2)}', 
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}
