import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supermarket/data/datasources/local/daos/customers_dao.dart';

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
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _buildHeader(account, startDate, endDate),
                  pw.SizedBox(height: 20),
                  _buildTransactionTable(transactions, account),
                  pw.SizedBox(height: 20),
                  _buildFooter(transactions, account),
                ],
              ),
            ),
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
        pw.Text('كشف حساب',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('Account Statement', style: const pw.TextStyle(fontSize: 18)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('اسم الحساب: ${account.name}'),
            pw.Text('كود الحساب: ${account.code}'),
          ],
        ),
        pw.Text(
            'الفترة: ${intl.DateFormat('yyyy-MM-dd').format(start)} - ${intl.DateFormat('yyyy-MM-dd').format(end)}'),
      ],
    );
  }

  pw.Widget _buildTransactionTable(
      List<AccountTransaction> transactions, GLAccount account) {
    final headers = ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'];
    double runningBalance = 0.0;

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: transactions.map((t) {
        if (account.type == 'ASSET' || account.type == 'EXPENSE') {
          runningBalance += (t.debit - t.credit).toDouble();
        } else {
          runningBalance += (t.credit - t.debit).toDouble();
        }
        return [
          intl.DateFormat('yyyy-MM-dd').format(t.date),
          t.type,
          t.debit.toStringAsFixed(2),
          t.credit.toStringAsFixed(2),
          runningBalance.toStringAsFixed(2),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerRight,
    );
  }

  pw.Widget _buildFooter(
      List<AccountTransaction> transactions, GLAccount account) {
    double totalDebit = transactions
        .fold<Decimal>(Decimal.zero, (sum, t) => sum + t.debit)
        .toDouble();
    double totalCredit = transactions
        .fold<Decimal>(Decimal.zero, (sum, t) => sum + t.credit)
        .toDouble();
    double finalBalance = 0.0;
    if (account.type == 'ASSET' || account.type == 'EXPENSE') {
      finalBalance = totalDebit - totalCredit;
    } else {
      finalBalance = totalCredit - totalDebit;
    }

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

  Future<void> printCustomerStatement({
    required Customer customer,
    required List<CustomerTransaction> transactions,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (pw.Context context) {
          double runningBalance = 0.0;
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('كشف حساب العميل',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Customer Statement',
                      style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('العميل: ${customer.name}'),
                      pw.Text('الهاتف: ${customer.phone ?? ""}'),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          'الرصيد الحالي في النظام: ${customer.balance.toStringAsFixed(2)} SAR'),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'التاريخ',
                      'البيان',
                      'مدين (عليه)',
                      'دائن (له)',
                      'الرصيد'
                    ],
                    data: transactions.map((t) {
                      runningBalance += t.debit - t.credit;
                      return [
                        intl.DateFormat('yyyy-MM-dd HH:mm').format(t.date),
                        t.description,
                        t.debit.toStringAsFixed(2),
                        t.credit.toStringAsFixed(2),
                        runningBalance.toStringAsFixed(2),
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    cellAlignment: pw.Alignment.centerRight,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'إجمالي المدين (المبيعات): ${transactions.fold<double>(0, (sum, t) => sum + t.debit).toStringAsFixed(2)} SAR'),
                      pw.Text(
                          'إجمالي الدائن (المسدد/المرتجع): ${transactions.fold<double>(0, (sum, t) => sum + t.credit).toStringAsFixed(2)} SAR'),
                      pw.Text(
                          'الرصيد النهائي المحسوب: ${runningBalance.toStringAsFixed(2)} SAR',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> printSupplierStatement({
    required Supplier supplier,
    required List<dynamic> transactions,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (pw.Context context) {
          final list = List.from(transactions);
          list.sort((a, b) {
            final dateA =
                a is Purchase ? a.date : (a as SupplierPayment).paymentDate;
            final dateB =
                b is Purchase ? b.date : (b as SupplierPayment).paymentDate;
            return dateA.compareTo(dateB);
          });

          double runningBalance = 0.0;

          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('كشف حساب المورد',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Supplier Statement',
                      style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المورد: ${supplier.name}'),
                      pw.Text('الهاتف: ${supplier.phone ?? ""}'),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          'الرصيد الحالي في النظام: ${supplier.balance.toStringAsFixed(2)} SAR'),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'التاريخ',
                      'البيان',
                      'مدين (+ شراء)',
                      'دائن (- تسديد)',
                      'الرصيد'
                    ],
                    data: list.map((tx) {
                      final date = tx is Purchase
                          ? tx.date
                          : (tx as SupplierPayment).paymentDate;
                      final typeStr = tx is Purchase
                          ? 'فاتورة مشتريات آجل ${tx.invoiceNumber != null ? "#${tx.invoiceNumber}" : ""}'
                          : 'دفعة للمورد';
                      final debit = tx is Purchase ? tx.total.toDouble() : 0.0;
                      final credit =
                          tx is SupplierPayment ? tx.amount.toDouble() : 0.0;
                      runningBalance += debit - credit;

                      return [
                        intl.DateFormat('yyyy-MM-dd HH:mm').format(date),
                        typeStr,
                        debit > 0 ? debit.toStringAsFixed(2) : '0.00',
                        credit > 0 ? credit.toStringAsFixed(2) : '0.00',
                        runningBalance.toStringAsFixed(2),
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    cellAlignment: pw.Alignment.centerRight,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'إجمالي المشتريات الآجلة (+): ${transactions.whereType<Purchase>().fold<double>(0, (sum, p) => sum + p.total.toDouble()).toStringAsFixed(2)} SAR'),
                      pw.Text(
                          'إجمالي المدفوعات للمورد (-): ${transactions.whereType<SupplierPayment>().fold<double>(0, (sum, sp) => sum + sp.amount.toDouble()).toStringAsFixed(2)} SAR'),
                      pw.Text(
                          'الرصيد النهائي المحسوب: ${runningBalance.toStringAsFixed(2)} SAR',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
