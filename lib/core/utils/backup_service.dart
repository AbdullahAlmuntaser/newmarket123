import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/logger.dart';

class LocalBackupInfo {
  const LocalBackupInfo({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class BackupService {
  static const String backupPrefix = 'supermarket_backup_';
  static const String backupExtension = '.sqlite';

  final AppDatabase db;

  BackupService(this.db);

  /// إنشاء نسخة احتياطية عبر نسخ ملف قاعدة البيانات مباشرة مع فحص سلامة البيانات
  Future<String> createLocalBackup() async {
    // 1. فحص سلامة قاعدة البيانات قبل النسخ
    final result = await db.customSelect('PRAGMA integrity_check;').get();
    final status = result.first.data.values.first as String;

    if (status != 'ok') {
      AppLogger.error('Database integrity check failed: $status');
      throw Exception(
          'لا يمكن إنشاء نسخة احتياطية: قاعدة البيانات تالفة ($status)');
    }

    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

    final dbFile = await _databaseFile();

    if (!await dbFile.exists()) {
      throw Exception('Database file not found');
    }

    final backupDir = await _backupDirectory();
    final backupPath = p.join(
      backupDir.path,
      '$backupPrefix${_backupTimestamp()}$backupExtension',
    );

    // نسخ الملف
    await dbFile.copy(backupPath);

    return backupPath;
  }

  Future<List<LocalBackupInfo>> listLocalBackups() async {
    final backupDir = await _backupDirectory();
    if (!await backupDir.exists()) return [];

    final backups = <LocalBackupInfo>[];
    await for (final entity in backupDir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(backupPrefix) || !name.endsWith(backupExtension)) {
        continue;
      }

      final stat = await entity.stat();
      backups.add(
        LocalBackupInfo(
          path: entity.path,
          name: name,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<void> deleteLocalBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final backupDir = await _backupDirectory();
    final backupDirPath = p.canonicalize(backupDir.path);
    final fileDirPath = p.canonicalize(file.parent.path);
    final fileName = p.basename(file.path);

    if (fileDirPath != backupDirPath ||
        !fileName.startsWith(backupPrefix) ||
        !fileName.endsWith(backupExtension)) {
      throw Exception('Invalid backup file path');
    }

    await file.delete();
  }

  /// استعادة البيانات عبر استبدال ملف قاعدة البيانات
  Future<String> restoreFromLocal(String filePath) async {
    final backupFile = File(filePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    _validateSqliteIntegrity(filePath);

    final dbFile = await _databaseFile();
    final backupDir = await _backupDirectory();
    final safetyBackupPath = p.join(
      backupDir.path,
      '${backupPrefix}pre_restore_${_backupTimestamp()}$backupExtension',
    );

    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

    if (await dbFile.exists()) {
      await dbFile.copy(safetyBackupPath);
    }

    // إغلاق قاعدة البيانات أولاً لتجنب قفل الملف
    await db.close();

    // استبدال الملف
    await backupFile.copy(dbFile.path);
    return safetyBackupPath;
  }

  Future<void> shareBackup(String filePath) async {
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(filePath)], text: 'ERP Database Backup');
  }

  // دعم النسخ الاحتياطي التلقائي (يومي)
  Future<void> runAutoBackup() async {
    try {
      final path = await createLocalBackup();
      AppLogger.info('Auto backup created at: $path');
      // Cloud upload disabled
    } catch (e) {
      AppLogger.error('Auto backup failed', error: e);
    }
  }

  Future<List<String>> listCloudBackups() async {
    return [];
  }

  Future<File> _databaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'app_db.sqlite'));
  }

  Future<Directory> _backupDirectory() async {
    final backupDir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  String _backupTimestamp() {
    return DateTime.now().toIso8601String().replaceAll(':', '-');
  }

  void _validateSqliteIntegrity(String filePath) {
    sqlite.Database? backupDb;
    try {
      backupDb = sqlite.sqlite3.open(filePath, mode: sqlite.OpenMode.readOnly);
      final result = backupDb.select('PRAGMA integrity_check;');
      final status = result.first['integrity_check'] as String;
      if (status != 'ok') {
        throw Exception('Backup integrity check failed: $status');
      }
    } finally {
      backupDb?.dispose();
    }
  }
}
