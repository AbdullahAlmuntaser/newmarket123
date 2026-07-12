#!/usr/bin/env dart

import 'dart:io';
import 'dart:developer' as developer;
import 'package:sqlite3/sqlite3.dart';

void logInfo(String message) => developer.log(message, name: 'tool.encrypt');
void logError(String message) =>
    developer.log(message, name: 'tool.encrypt', level: 1000);

void usage() {
  logInfo('''
Usage: dart run tool/convert_to_encrypted.dart <source-db-path> [--out <target-db-path>] [--key <passphrase>]

This tool creates an encrypted copy of an existing SQLite database using ATTACH ... KEY.
The underlying sqlite3 library must be built with SQLCipher support for encryption to succeed.
If --key is omitted the tool will prompt for a passphrase. Do NOT store the passphrase in repo.
''');
}

String readKeyFromStdin() {
  stdout.write('Enter encryption passphrase: ');
  final key = stdin.readLineSync();
  if (key == null || key.isEmpty) {
    logError('No key provided');
    exit(2);
  }
  return key;
}

void main(List<String> args) {
  if (args.isEmpty) {
    usage();
    exit(1);
  }

  final source = args[0];
  String? out;
  String? key;

  for (var i = 1; i < args.length; i++) {
    final a = args[i];
    if (a == '--out' && i + 1 < args.length) {
      out = args[++i];
    } else if (a == '--key' && i + 1 < args.length) {
      key = args[++i];
    } else if (a == '--help' || a == '-h') {
      usage();
      exit(0);
    } else {
      logError('Unknown arg: $a');
      usage();
      exit(1);
    }
  }

  final sourceFile = File(source);
  if (!sourceFile.existsSync()) {
    logError('Source DB not found: $source');
    exit(2);
  }

  out ??=
      '${sourceFile.parent.path}${Platform.pathSeparator}${sourceFile.uri.pathSegments.last}.encrypted.sqlite';

  key ??= readKeyFromStdin();

  logInfo('Source: $source');
  logInfo('Target: $out');

  // Make sure target does not exist
  final outFile = File(out);
  if (outFile.existsSync()) {
    logError('Target already exists: ${outFile.path}');
    logError('Remove it or choose a different --out path.');
    exit(3);
  }

  // Open source DB
  final db = sqlite3.open(source);
  try {
    // Integrity check
    final res = db.select("PRAGMA integrity_check;");
    if (res.isEmpty) {
      logError('integrity_check returned no rows');
      exit(4);
    }
    final status = res.first.values.first;
    if (status != 'ok') {
      logError('Source DB integrity_check failed: $status');
      exit(5);
    }

    logInfo('Source integrity_check: $status');

    // Attempt ATTACH ... KEY - requires SQLCipher-enabled sqlite3
    try {
      db.execute(
          "ATTACH DATABASE '${outFile.path.replaceAll("'", "''")}' AS encrypted KEY '$key';");
    } catch (e) {
      logError(
          'Failed to attach encrypted database. Likely sqlite3 was not built with SQLCipher.');
      logError('Error: $e');
      db.dispose();
      exit(6);
    }

    // Create tables in attached DB
    final tables = <String>[];
    final tableRows = db.select(
        "SELECT name, sql, type FROM main.sqlite_master WHERE sql NOT NULL AND type IN ('table','index','trigger','view') ORDER BY type='table' DESC, type='index' DESC;");

    // First create tables only
    for (final row in tableRows) {
      final type = row['type'] as String;
      final name = row['name'] as String;
      final sql = row['sql'] as String;
      if (type == 'table') {
        // create in encrypted by prefixing name
        final modified = sql.replaceFirst(
            RegExp(r"CREATE TABLE\s+" + RegExp.escape(name)),
            "CREATE TABLE encrypted.$name");
        db.execute(modified);
        tables.add(name);
      }
    }

    // Then create indexes, triggers, views
    for (final row in tableRows) {
      final type = row['type'] as String;
      final name = row['name'] as String;
      final sql = row['sql'] as String;
      if (type != 'table') {
        final modified =
            sql.replaceFirst(RegExp(r"\b$name\b"), 'encrypted.$name');
        try {
          db.execute(modified);
        } catch (e) {
          // index creation may reference table names; if fails try original sql on encrypted without renaming index name
          try {
            final fallback = sql.replaceFirst(
                RegExp(r"CREATE INDEX\s+"), 'CREATE INDEX encrypted.');
            db.execute(fallback);
          } catch (_) {
            // ignore failures for non-critical index/trigger creation
          }
        }
      }
    }

    // Copy data
    for (final t in tables) {
      logInfo('Copying table: $t');
      db.execute("INSERT INTO encrypted.$t SELECT * FROM main.$t;");
    }

    // Detach
    db.execute('DETACH DATABASE encrypted;');

    db.dispose();

    // Verify new DB integrity
    final newDb = sqlite3.open(outFile.path);
    try {
      final res2 = newDb.select('PRAGMA integrity_check;');
      final status2 = res2.first.values.first;
      logInfo('New DB integrity_check: $status2');
      if (status2 != 'ok') {
        logError('Encrypted DB integrity check failed: $status2');
        newDb.dispose();
        exit(7);
      }
    } finally {
      newDb.dispose();
    }

    logInfo('Encrypted database created successfully at: ${outFile.path}');
  } finally {
    db.dispose();
  }
}
