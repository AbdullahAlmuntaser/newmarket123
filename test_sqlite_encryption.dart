// ignore_for_file: avoid_print
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

void main() {
  final file = File('test_encryption.db');
  if (file.existsSync()) file.deleteSync();

  final db = sqlite3.open(file.path);
  try {
    print('Executing PRAGMA key...');
    db.execute("PRAGMA key = 'testkey'");
    print('PRAGMA key executed.');

    print('Executing SELECT count(*) FROM sqlite_master...');
    final result = db.select('SELECT count(*) FROM sqlite_master');
    // ignore: collection_methods_unrelated_type
    print('Result: ${result.first[0]}');
  } catch (e) {
    print('Caught error: $e');
  } finally {
    db.dispose();
  }
}
