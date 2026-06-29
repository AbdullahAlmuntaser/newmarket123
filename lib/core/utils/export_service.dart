import 'package:csv/csv.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ExportFormat { csv, pdf, excel }

enum ExportType {
  products,
  customers,
  suppliers,
  sales,
  purchases,
  inventory,
  invoices
}

class ExportService {
  final AppDatabase db;

  ExportService(this.db);

  Future<String> exportProducts(
      {ExportFormat format = ExportFormat.csv}) async {
    final products = await db.select(db.products).get();

    List<List<dynamic>> rows = [];
    rows.add(
        ["ID", "Name", "SKU", "Barcode", "Sell Price", "Buy Price", "Stock"]);

    for (var p in products) {
      rows.add([
        p.id,
        p.name,
        p.sku,
        p.barcode,
        p.sellPrice.toString(),
        p.buyPrice.toString(),
        p.stock.toString(),
      ]);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    switch (format) {
      case ExportFormat.csv:
        return await _exportToCsv(rows, 'products_$timestamp');
      case ExportFormat.pdf:
        return await _exportToPdf(
            rows, 'Products Report', 'products_$timestamp');
      case ExportFormat.excel:
        return await _exportToExcel(rows, 'products_$timestamp', 'المنتجات');
    }
  }

  Future<String> exportCustomers(
      {ExportFormat format = ExportFormat.csv}) async {
    final customers = await db.select(db.customers).get();

    List<List<dynamic>> rows = [];
    rows.add([
      "ID",
      "Name",
      "Phone",
      "Email",
      "Address",
      "Tax Number",
      "Credit Limit"
    ]);

    for (var c in customers) {
      rows.add([
        c.id,
        c.name,
        c.phone,
        c.email,
        c.address,
        c.taxNumber,
        c.creditLimit.toString(),
      ]);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    switch (format) {
      case ExportFormat.csv:
        return await _exportToCsv(rows, 'customers_$timestamp');
      case ExportFormat.pdf:
        return await _exportToPdf(
            rows, 'Customers Report', 'customers_$timestamp');
      case ExportFormat.excel:
        return await _exportToExcel(rows, 'customers_$timestamp', 'العملاء');
    }
  }

  Future<String> exportSuppliers(
      {ExportFormat format = ExportFormat.csv}) async {
    final suppliers = await db.select(db.suppliers).get();

    List<List<dynamic>> rows = [];
    rows.add(
        ["ID", "Name", "Phone", "Email", "Address", "Tax Number", "Balance"]);

    for (var s in suppliers) {
      rows.add([
        s.id,
        s.name,
        s.phone,
        s.email,
        s.address,
        s.taxNumber,
        s.balance.toString(),
      ]);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    switch (format) {
      case ExportFormat.csv:
        return await _exportToCsv(rows, 'suppliers_$timestamp');
      case ExportFormat.pdf:
        return await _exportToPdf(
            rows, 'Suppliers Report', 'suppliers_$timestamp');
      case ExportFormat.excel:
        return await _exportToExcel(rows, 'suppliers_$timestamp', 'الموردين');
    }
  }

  Future<String> exportSales(
      {DateTime? from,
      DateTime? to,
      ExportFormat format = ExportFormat.csv}) async {
    var query = db.select(db.sales);

    final sales = await query.get();

    List<List<dynamic>> rows = [];
    rows.add(["ID", "Customer", "Total", "Status"]);

    for (var s in sales) {
      rows.add([
        s.id,
        s.customerId ?? '',
        s.total.toString(),
        s.status.name,
      ]);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    switch (format) {
      case ExportFormat.csv:
        return await _exportToCsv(rows, 'sales_$timestamp');
      case ExportFormat.pdf:
        return await _exportToPdf(rows, 'Sales Report', 'sales_$timestamp');
      case ExportFormat.excel:
        return await _exportToExcel(rows, 'sales_$timestamp', 'المبيعات');
    }
  }

  Future<String> exportInventory(
      {ExportFormat format = ExportFormat.csv}) async {
    final products = await db.select(db.products).get();

    List<List<dynamic>> rows = [];
    rows.add([
      "Product",
      "SKU",
      "Barcode",
      "Stock",
      "Buy Price",
      "Sell Price",
      "Value"
    ]);

    for (var p in products) {
      final value = p.stock * p.buyPrice;
      rows.add([
        p.name,
        p.sku,
        p.barcode,
        p.stock.toString(),
        p.buyPrice.toString(),
        p.sellPrice.toString(),
        value.toString(),
      ]);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    switch (format) {
      case ExportFormat.csv:
        return await _exportToCsv(rows, 'inventory_$timestamp');
      case ExportFormat.pdf:
        return await _exportToPdf(
            rows, 'Inventory Report', 'inventory_$timestamp');
      case ExportFormat.excel:
        return await _exportToExcel(rows, 'inventory_$timestamp', 'المخزون');
    }
  }

  Future<String> _exportToCsv(List<List<dynamic>> rows, String filename) async {
    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.csv');
    await file.writeAsString(csvData);

    return file.path;
  }

  Future<String> _exportToExcel(
      List<List<dynamic>> rows, String filename, String sheetName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.csv');

    final buffer = StringBuffer();
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      buffer.write(row.map((cell) {
        final str = cell?.toString() ?? '';
        if (str.contains(',') || str.contains('"') || str.contains('\n')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      }).join(','));
      if (i < rows.length - 1) buffer.write('\n');
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _exportToPdf(
      List<List<dynamic>> rows, String title, String filename) async {
    final pdf = pw.Document();

    final headers = rows.isNotEmpty ? rows.first : [];
    final data = rows.length > 1 ? rows.sublist(1) : <List<dynamic>>[];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('تاريخ التصدير: ${DateTime.now().toString()}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.all(5),
              headers: headers.map((e) => e.toString()).toList(),
              data: data
                  .map((row) => row.map((e) => e?.toString() ?? '').toList())
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('إجمالي السجلات: ${data.length}'),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    return file.path;
  }

  String generateCsvTemplate(ExportType type) {
    List<String> headers;

    switch (type) {
      case ExportType.products:
        headers = [
          'name',
          'sku',
          'barcode',
          'sell_price',
          'buy_price',
          'stock',
          'category'
        ];
        break;
      case ExportType.customers:
        headers = [
          'name',
          'phone',
          'email',
          'address',
          'tax_number',
          'credit_limit'
        ];
        break;
      case ExportType.suppliers:
        headers = ['name', 'phone', 'email', 'address', 'tax_number'];
        break;
      case ExportType.inventory:
        headers = ['product_id', 'warehouse_id', 'quantity', 'expiry_date'];
        break;
      default:
        headers = [];
    }

    return headers.join(',');
  }

  Future<void> exportToPdf(
      String title, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    final headers = data.first.keys.toList();
    final rows = data
        .map((row) => headers.map((h) => row[h]?.toString() ?? '').toList())
        .toList();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.all(5),
              headers: headers,
              data: rows,
            ),
            pw.SizedBox(height: 20),
            pw.Text('Generated: ${DateTime.now().toString()}'),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/${title}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
  }

  Future<void> exportToCsv(
      String title, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    final headers = data.first.keys.toList();
    final rows = <List<dynamic>>[headers];
    for (final row in data) {
      rows.add(headers.map((h) => row[h]?.toString() ?? '').toList());
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/${title}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);
  }

  Future<String> exportToExcelFile(
      String title, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return '';

    final headers = data.first.keys.toList();
    final rows = <List<dynamic>>[headers];
    for (final row in data) {
      rows.add(headers.map((h) => row[h]?.toString() ?? '').toList());
    }

    return await _exportToExcel(
        rows, '${title}_${DateTime.now().millisecondsSinceEpoch}', title);
  }
}
