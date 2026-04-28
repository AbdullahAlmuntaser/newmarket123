import 'package:csv/csv.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExportService {
  final AppDatabase db;

  ExportService(this.db);

  /// Exports products to a CSV file
  Future<String> exportProducts() async {
    final products = await db.select(db.products).get();
    
    List<List<dynamic>> rows = [];
    // Header
    rows.add(["ID", "Name", "SKU", "Barcode", "Price", "Stock"]);

    for (var p in products) {
      rows.add([p.id, p.name, p.sku, p.barcode, p.sellPrice, p.stock]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/products_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);
    
    return file.path;
  }
}
