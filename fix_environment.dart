import 'dart:io';
import 'package:flutter/foundation.dart';

void main() {
  // Simple check for problematic dependency usage
  final pubspec = File('pubspec.yaml').readAsStringSync();
  if (pubspec.contains('sqlite3') && pubspec.contains('web')) {
    debugPrint(
        'Warning: sqlite3 might cause FFI issues on web. Check your configuration.');
  }
}
