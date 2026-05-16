import 'dart:io';
import 'package:path/path.dart' as path;

enum ImportType { products, customers, suppliers, inventory }

class ImportResult {
  final int successCount;
  final int failureCount;
  final List<String> errors;
  final List<Map<String, dynamic>> importedData;

  ImportResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
    required this.importedData,
  });

  bool get hasErrors => failureCount > 0;
  int get totalCount => successCount + failureCount;
}

class DataImportService {
  Future<ImportResult> importFromCsv(String filePath, ImportType type) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          successCount: 0,
          failureCount: 0,
          errors: ['File not found: $filePath'],
          importedData: [],
        );
      }

      final content = await file.readAsString();
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      
      if (lines.isEmpty) {
        return ImportResult(
          successCount: 0,
          failureCount: 0,
          errors: ['File is empty'],
          importedData: [],
        );
      }

      final headers = _parseCsvLine(lines.first);
      final data = <Map<String, dynamic>>[];
      final errors = <String>[];
      int successCount = 0;
      int failureCount = 0;

      for (int i = 1; i < lines.length; i++) {
        try {
          final values = _parseCsvLine(lines[i]);
          if (values.length != headers.length) {
            errors.add('Row $i: Column count mismatch');
            failureCount++;
            continue;
          }

          final row = <String, dynamic>{};
          for (int j = 0; j < headers.length; j++) {
            row[headers[j]] = values[j].trim();
          }

          final validation = _validateRow(row, type, i);
          if (validation != null) {
            errors.add(validation);
            failureCount++;
            continue;
          }

          data.add(row);
          successCount++;
        } catch (e) {
          errors.add('Row $i: ${e.toString()}');
          failureCount++;
        }
      }

      return ImportResult(
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
        importedData: data,
      );
    } catch (e) {
      return ImportResult(
        successCount: 0,
        failureCount: 0,
        errors: ['Import failed: ${e.toString()}'],
        importedData: [],
      );
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    
    return result;
  }

  String? _validateRow(Map<String, dynamic> row, ImportType type, int rowNum) {
    switch (type) {
      case ImportType.products:
        if (row['name'] == null || row['name'].toString().isEmpty) {
          return 'Row $rowNum: Product name is required';
        }
        if (row['barcode'] != null && row['barcode'].toString().isNotEmpty) {
          if (row['barcode'].toString().length < 4) {
            return 'Row $rowNum: Invalid barcode length';
          }
        }
        break;
      case ImportType.customers:
        if (row['name'] == null || row['name'].toString().isEmpty) {
          return 'Row $rowNum: Customer name is required';
        }
        break;
      case ImportType.suppliers:
        if (row['name'] == null || row['name'].toString().isEmpty) {
          return 'Row $rowNum: Supplier name is required';
        }
        break;
      case ImportType.inventory:
        if (row['product_id'] == null || row['product_id'].toString().isEmpty) {
          return 'Row $rowNum: Product ID is required';
        }
        if (row['quantity'] == null) {
          return 'Row $rowNum: Quantity is required';
        }
        break;
    }
    return null;
  }

  List<String> getCsvTemplate(ImportType type) {
    switch (type) {
      case ImportType.products:
        return ['name', 'barcode', 'sku', 'category', 'sell_price', 'buy_price', 'unit', 'tax_type'];
      case ImportType.customers:
        return ['name', 'phone', 'email', 'address', 'tax_number', 'credit_limit'];
      case ImportType.suppliers:
        return ['name', 'phone', 'email', 'address', 'tax_number', 'payment_terms'];
      case ImportType.inventory:
        return ['product_id', 'warehouse_id', 'quantity', 'expiry_date'];
    }
  }

  String generateTemplateCsv(ImportType type) {
    final headers = getCsvTemplate(type);
    return headers.join(',');
  }

  Future<bool> isValidFile(String filePath) async {
    final ext = path.extension(filePath).toLowerCase();
    return ['.csv', '.xlsx', '.xls'].contains(ext);
  }

  String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }
}