import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  Future<String> createLocalBackup() async {
    final allTables = db.allTables.toList();
    final backupData = <String, List<Map<String, dynamic>>>{};

    for (final table in allTables) {
      final tableData = await (db.select(table as dynamic)).get();
      backupData[table.actualTableName] = tableData
          .map((row) => (row as dynamic).toJson() as Map<String, dynamic>)
          .toList();
    }

    final jsonString = jsonEncode(backupData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/supermarket_backup_${DateTime.now().toIso8601String()}.json');
    await file.writeAsString(jsonString);
    return file.path;
  }

  Future<void> restoreFromLocal(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    await db.transaction(() async {
      for (final table in db.allTables) {
        final tableName = table.actualTableName;
        if (backupData.containsKey(tableName)) {
          await db.delete(table).go();

          final tableData = backupData[tableName] as List;
          for (final row in tableData) {
            await db.into(table).insert(
                  (table as dynamic)
                      .fromData(row as Map<String, dynamic>),
                );
          }
        }
      }
    });
  }

  Future<void> shareBackup(String filePath) async {
    // Corrected according to the latest SharePlus documentation
    await Share.shareXFiles([XFile(filePath)], text: 'Supermarket Database Backup');
  }

  Future<List<String>> listCloudBackups() async {
    // Planned for future update
    return [];
  }

  Future<void> uploadToFirebase(String filePath) async {
    // Planned for future update
  }

  Future<void> downloadAndRestore(String fileName) async {
    // Planned for future update
  }
}
