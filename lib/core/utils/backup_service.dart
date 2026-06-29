import 'package:share_plus/share_plus.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/backup/backup_service.dart'
    as unified_backup;

// Adapter: keep the old lightweight API but delegate to the unified
// BackupService implementation in lib/core/services/backup/backup_service.dart.

class LocalBackupInfo {
  final String path;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  const LocalBackupInfo({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  Future<String> createLocalBackup() async {
    final unified = unified_backup.BackupService(db);
    final result = await unified.createBackup();
    if (!result.success) throw Exception(result.message);
    return result.backupPath ?? '';
  }

  Future<List<LocalBackupInfo>> listLocalBackups() async {
    final unified = unified_backup.BackupService(db);
    final metas = await unified.listBackups();
    return metas
        .map((m) => LocalBackupInfo(
              path: m.databasePath,
              name: m.backupName,
              createdAt: m.backupDate,
              sizeBytes: m.fileSize,
            ))
        .toList();
  }

  Future<void> deleteLocalBackup(String filePath) async {
    final unified = unified_backup.BackupService(db);
    await unified.deleteBackup(filePath);
  }

  Future<String> restoreFromLocal(String filePath) async {
    final unified = unified_backup.BackupService(db);
    final result = await unified.restoreBackup(filePath);
    if (!result.success) throw Exception(result.message);
    return result.backupPath ?? '';
  }

  Future<void> shareBackup(String filePath) async {
    // Delegate to share_plus directly
    await Share.shareXFiles([XFile(filePath)], text: 'ERP Database Backup');
  }
}

// (alias import moved to top)
