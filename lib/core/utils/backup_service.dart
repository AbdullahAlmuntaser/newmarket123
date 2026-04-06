import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/logger.dart';

class BackupService {
  final AppDatabase db;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  BackupService(this.db);

  /// إنشاء نسخة احتياطية عبر نسخ ملف قاعدة البيانات مباشرة
  Future<String> createLocalBackup() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

    if (!await dbFile.exists()) {
      throw Exception('Database file not found');
    }

    final backupDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = p.join(backupDir.path, 'supermarket_backup_$timestamp.sqlite');

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
      await uploadToFirebase(path);
    } catch (e) {
      AppLogger.error('Auto backup failed', error: e);
    }
  }

  Future<List<String>> listCloudBackups() async {
    try {
      final ListResult result = await _storage.ref('backups').listAll();
      return result.items.map((ref) => ref.name).toList();
    } catch (e) {
      AppLogger.error('Failed to list cloud backups', error: e);
      return [];
    }
  }

  Future<void> uploadToFirebase(String filePath) async {
    try {
      final file = File(filePath);
      final fileName = p.basename(filePath);
      await _storage.ref('backups/$fileName').putFile(file);
      AppLogger.info('Backup uploaded to cloud: $fileName');
    } catch (e) {
      AppLogger.error('Cloud upload failed', error: e);
    }
  }

  Future<void> downloadAndRestore(String fileName) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final downloadPath = p.join(dbFolder.path, 'downloaded_$fileName');
      final file = File(downloadPath);

      await _storage.ref('backups/$fileName').writeToFile(file);
      await restoreFromLocal(downloadPath);
      AppLogger.info('Backup downloaded and restored: $fileName');
    } catch (e) {
      AppLogger.error('Cloud restore failed', error: e);
      rethrow;
    }
  }
}
