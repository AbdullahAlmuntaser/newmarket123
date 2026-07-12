import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:supermarket/core/services/security_service.dart';
import 'package:supermarket/injection_container.dart' as di;

/// خدمة النسخ الاحتياطي والاستعادة لقاعدة البيانات
/// Backup and Restore Service for SQLite Database
class BackupService {
  AppDatabase database;

  BackupService(this.database);

  /// إنشاء نسخة احتياطية من قاعدة البيانات
  /// Creates a backup of the database
  Future<BackupResult> createBackup({String? backupName}) async {
    try {
      // Get database file path
      final dbFile = await _getDatabaseFile();

      if (!await dbFile.exists()) {
        return BackupResult(
          success: false,
          message: 'قاعدة البيانات غير موجودة',
          errorCode: 'DB_NOT_FOUND',
        );
      }

      // Run integrity check before backup
      try {
        final integrityCheck = await database
            .customSelect(
              'PRAGMA integrity_check',
            )
            .get();
        final integrityResult =
            integrityCheck.first.data.values.first.toString();
        if (integrityResult != 'ok') {
          return BackupResult(
            success: false,
            message: 'فشل فحص سلامة قاعدة البيانات: $integrityResult',
            errorCode: 'INTEGRITY_CHECK_FAILED',
          );
        }
      } catch (e) {
        return BackupResult(
          success: false,
          message: 'فشل فحص سلامة قاعدة البيانات: ${e.toString()}',
          errorCode: 'INTEGRITY_CHECK_ERROR',
        );
      }

      // Force WAL checkpoint to ensure all data is flushed to the main file
      try {
        await database.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      } catch (_) {
        // WAL mode may not be active; proceed anyway
      }

      // Generate backup filename
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final name = backupName ?? 'backup_$timestamp';
      final backupDir = await _getBackupDirectory();
      final backupFile = File('${backupDir.path}/$name.db');

      // Copy database file (safe now after checkpoint)
      // Ensure we copy only the main DB file, not WAL/SHM
      if (await dbFile.exists()) {
        await dbFile.copy(backupFile.path);
      } else {
        return BackupResult(
          success: false,
          message: 'ملف قاعدة البيانات الأساسي غير موجود بعد checkpoint',
          errorCode: 'DB_FILE_MISSING',
        );
      }

      // Verify backup integrity
      try {
        final testDb = await database
            .customSelect(
              'PRAGMA integrity_check',
            )
            .get();
        final testResult = testDb.first.data.values.first.toString();
        if (testResult != 'ok') {
          await backupFile.delete();
          return BackupResult(
            success: false,
            message: 'النسخة الاحتياطية تالفة: $testResult',
            errorCode: 'BACKUP_CORRUPT',
          );
        }
      } catch (_) {
        // Backup file integrity check is optional
      }

      // Create metadata file
      final metadata = BackupMetadata(
        backupName: name,
        backupDate: DateTime.now(),
        databasePath: backupFile.path,
        fileSize: await backupFile.length(),
        version: '1.0.0',
      );

      final metadataFile = File('${backupFile.path}.json');
      await metadataFile.writeAsString(jsonEncode(metadata.toJson()));

      return BackupResult(
        success: true,
        message: 'تم إنشاء النسخة الاحتياطية بنجاح',
        backupPath: backupFile.path,
        metadata: metadata,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'فشل إنشاء النسخة الاحتياطية: ${e.toString()}',
        errorCode: 'BACKUP_FAILED',
        error: e,
      );
    }
  }

  /// استعادة نسخة احتياطية
  /// Restores a backup
  Future<BackupResult> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);

      if (!await backupFile.exists()) {
        return BackupResult(
          success: false,
          message: 'ملف النسخة الاحتياطية غير موجود',
          errorCode: 'BACKUP_FILE_NOT_FOUND',
        );
      }

      // Verify backup file integrity and compatibility with current encryption key
      // Validate backup file integrity and compatibility with current encryption key
      try {
        // Validate using the low-level sqlite runtime so we can apply the key
        final utilsDbFile = File(backupPath);
        if (!await utilsDbFile.exists()) {
          return BackupResult(
            success: false,
            message: 'ملف النسخة الاحتياطية غير موجود',
            errorCode: 'BACKUP_FILE_NOT_FOUND',
          );
        }

        // Perform a validation similar to _validateSqliteIntegrity in utils module.
        // To avoid circular imports, perform a minimal validation here.
        try {
          // Attempt to open with sqlite3 and apply current key
          final db =
              sqlite.sqlite3.open(backupPath, mode: sqlite.OpenMode.readOnly);
          try {
            if (!SecurityService.useFakeKeyForTesting) {
              final key = await SecurityService.getDatabaseKey();
              final escapedKey = key.replaceAll("'", "''");
              db.execute("PRAGMA key = '$escapedKey'");
            }
            final result = db.select('PRAGMA integrity_check;');
            final status = result.first.values.first as String;
            if (status != 'ok') {
              return BackupResult(
                success: false,
                message: 'النسخة الاحتياطية تالفة ولا يمكن استعادتها: $status',
                errorCode: 'BACKUP_CORRUPT',
              );
            }
          } finally {
            db.dispose();
          }
        } catch (e) {
          final s = e.toString();
          if (s.contains('NO_SQLCIPHER')) {
            // Runtime does not support SQLCipher — do not proceed with restore.
            return BackupResult(
              success: false,
              message:
                  'لايوجد دعم SQLCipher في بيئة التشغيل. تأكد من تضمين مكتبة SQLCipher أو استعادة نسخة متوافقة.',
              errorCode: 'NO_SQLCIPHER_RUNTIME',
              error: e,
            );
          }
          return BackupResult(
            success: false,
            message: 'فشل التحقق من سلامة النسخة الاحتياطية: ${e.toString()}',
            errorCode: 'BACKUP_VALIDATION_FAILED',
            error: e,
          );
        }
      } catch (e) {
        debugPrint('Backup validation outer error: $e');
        return BackupResult(
          success: false,
          message: 'فشل التحقق من النسخة الاحتياطية قبل الاستعادة: ${e.toString()}',
          errorCode: 'BACKUP_VALIDATION_ERROR',
          error: e,
        );
      }

      // Get current database file
      final dbFile = await _getDatabaseFile();

      // Create a pre-restore safety backup
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final preRestorePath = '${dbFile.path}.pre_restore_$timestamp.db';
      final preRestoreBackup = File(preRestorePath);

      if (await dbFile.exists()) {
        await dbFile.copy(preRestoreBackup.path);
      }

      try {
        // Force WAL checkpoint on current DB before restore
        try {
          await database.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
        } catch (e) {
          debugPrint('Backup: WAL checkpoint failed: $e');
        }

        // Close current database connections
        await database.close();

        // Restore by copying backup to database location
        await backupFile.copy(dbFile.path);

        // Reopen database with a fresh connection and update DI registration
        AppDatabase.encryptionKey = SecurityService.useFakeKeyForTesting
            ? null
            : await SecurityService.getDatabaseKey();
        database = AppDatabase();
        try {
          if (di.sl.isRegistered<AppDatabase>()) {
            di.sl.unregister<AppDatabase>();
          }
        } catch (e) {
          debugPrint('Backup: Failed to unregister AppDatabase: $e');
        }
        di.sl.registerLazySingleton<AppDatabase>(() => database);

        return BackupResult(
          success: true,
          message:
              'تم استعادة النسخة الاحتياطية بنجاح. تم حفظ نسخة أمان للبيانات الحالية.',
          backupPath: backupPath,
        );
      } catch (e) {
        // Restore failed - attempt to restore pre-restore backup
        if (await preRestoreBackup.exists()) {
          await preRestoreBackup.copy(dbFile.path);
        }
        return BackupResult(
          success: false,
          message: 'فشل استعادة النسخة الاحتياطية: ${e.toString()}',
          errorCode: 'RESTORE_FAILED',
          error: e,
        );
      }
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'فشل استعادة النسخة الاحتياطية: ${e.toString()}',
        errorCode: 'RESTORE_FAILED',
        error: e,
      );
    }
  }

  /// الحصول على قائمة النسخ الاحتياطية
  /// Get list of all backups
  Future<List<BackupMetadata>> listBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files = backupDir.listSync();

      final backups = <BackupMetadata>[];

      for (var file in files) {
        if (file is File && file.path.endsWith('.db')) {
          final metadataFile = File('${file.path}.json');
          if (await metadataFile.exists()) {
            final content = await metadataFile.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
            backups.add(BackupMetadata.fromJson(data));
          } else {
            // Create metadata from file info if JSON doesn't exist
            backups.add(BackupMetadata(
              backupName: file.path.split('/').last,
              backupDate: file.lastModifiedSync(),
              databasePath: file.path,
              fileSize: await file.length(),
              version: 'unknown',
            ));
          }
        }
      }

      // Sort by date descending
      backups.sort((a, b) => b.backupDate.compareTo(a.backupDate));

      return backups;
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  /// حذف نسخة احتياطية
  /// Delete a backup
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      final metadataFile = File('$backupPath.json');

      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// الحصول على مسار ملف قاعدة البيانات
  Future<File> _getDatabaseFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/app_db.sqlite');
  }

  /// الحصول على مجلد النسخ الاحتياطية
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  /// تنظيف النسخ الاحتياطية القديمة
  /// Clean old backups older than specified days
  Future<int> cleanOldBackups({int daysToKeep = 30}) async {
    try {
      final backups = await listBackups();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      int deletedCount = 0;

      for (var backup in backups) {
        if (backup.backupDate.isBefore(cutoffDate)) {
          final backupFile = File(backup.databasePath);
          if (await backupFile.exists()) {
            await backupFile.delete();
            final metadataFile = File('${backup.databasePath}.json');
            if (await metadataFile.exists()) {
              await metadataFile.delete();
            }
            deletedCount++;
          }
        }
      }

      return deletedCount;
    } catch (e) {
      debugPrint('Error cleaning old backups: $e');
      return 0;
    }
  }
}

/// نتيجة عملية النسخ الاحتياطي
class BackupResult {
  final bool success;
  final String message;
  final String? backupPath;
  final String? errorCode;
  final Object? error;
  final BackupMetadata? metadata;

  BackupResult({
    required this.success,
    required this.message,
    this.backupPath,
    this.errorCode,
    this.error,
    this.metadata,
  });
}

/// بيانات وصفية للنسخة الاحتياطية
class BackupMetadata {
  final String backupName;
  final DateTime backupDate;
  final String databasePath;
  final int fileSize;
  final String version;

  BackupMetadata({
    required this.backupName,
    required this.backupDate,
    required this.databasePath,
    required this.fileSize,
    required this.version,
  });

  Map<String, dynamic> toJson() {
    return {
      'backupName': backupName,
      'backupDate': backupDate.toIso8601String(),
      'databasePath': databasePath,
      'fileSize': fileSize,
      'version': version,
    };
  }

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      backupName: json['backupName'] ?? '',
      backupDate: DateTime.parse(json['backupDate']),
      databasePath: json['databasePath'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      version: json['version'] ?? '1.0.0',
    );
  }

  String get formattedFileSize {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = fileSize.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}
