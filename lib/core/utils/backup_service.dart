import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/logger.dart';

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  /// إنشاء نسخة احتياطية عبر نسخ ملف قاعدة البيانات مباشرة
  Future<String> createLocalBackup() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

    if (!await dbFile.exists()) {
      throw Exception('Database file not found');
    }

    final backupDir =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = p.join(
      backupDir.path,
      'supermarket_backup_$timestamp.sqlite',
    );

    // نسخ الملف
    await dbFile.copy(backupPath);

    return backupPath;
  }

  /// استعادة البيانات عبر استبدال ملف قاعدة البيانات
  Future<void> restoreFromLocal(String filePath) async {
    final backupFile = File(filePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

    // إغلاق قاعدة البيانات أولاً لتجنب قفل الملف
    await db.close();

    // استبدال الملف
    await backupFile.copy(dbFile.path);
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
    // Disabled as Firebase is removed
    return [];
  }

  Future<void> uploadToFirebase(String filePath) async {
    // Disabled
  }

  Future<void> downloadAndRestore(String fileName) async {
    // Disabled
  }
}
