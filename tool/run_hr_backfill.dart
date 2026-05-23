import 'dart:io';
import 'dart:developer' as developer;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/native.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    developer.log('Usage: dart run tool/run_hr_backfill.dart <path-to-sqlite-db> [--dry-run] [--verbose]', name: 'tool.run_hr_backfill');
    exit(1);
  }

  final path = args[0];
  final dryRun = args.contains('--dry-run');
  final verbose = args.contains('--verbose');

  final file = File(path);
  if (!file.existsSync()) {
    developer.log('Database file not found: $path', name: 'tool.run_hr_backfill');
    exit(2);
  }

  final db = AppDatabase(NativeDatabase(file));
  try {
    developer.log('Running HR backfill on $path (dryRun=$dryRun)', name: 'tool.run_hr_backfill');
    await db.runHrBackfill(dryRun: dryRun, verbose: verbose);
    developer.log('HR backfill completed', name: 'tool.run_hr_backfill');
  } catch (e, st) {
    developer.log('HR backfill failed: $e', name: 'tool.run_hr_backfill', level: 1000);
    developer.log('$st', name: 'tool.run_hr_backfill', level: 1000);
    rethrow;
  } finally {
    await db.close();
  }
}
