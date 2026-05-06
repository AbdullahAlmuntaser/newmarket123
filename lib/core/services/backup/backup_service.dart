import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:newmarket/data/local/db/app_database.dart';

/// خدمة النسخ الاحتياطي والاستعادة لقاعدة البيانات
/// Backup and Restore Service for SQLite Database
class BackupService {
  final AppDatabase database;

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

      // Generate backup filename
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final name = backupName ?? 'backup_$timestamp';
      final backupDir = await _getBackupDirectory();
      final backupFile = File('${backupDir.path}/$name.db');

      // Copy database file
      await dbFile.copy(backupFile.path);

      // Create metadata file
      final metadata = BackupMetadata(
        backupName: name,
        backupDate: DateTime.now(),
        databasePath: dbFile.path,
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

      // Get current database file
      final dbFile = await _getDatabaseFile();
      
      // Create a temporary backup of current database before restore
      if (await dbFile.exists()) {
        final preRestoreBackup = File(
          '${dbFile.path}.pre_restore_${DateTime.now().millisecondsSinceEpoch}.db'
        );
        await dbFile.copy(preRestoreBackup.path);
      }

      // Restore by copying backup to database location
      await backupFile.copy(dbFile.path);

      return BackupResult(
        success: true,
        message: 'تم استعادة النسخة الاحتياطية بنجاح',
        backupPath: backupPath,
      );
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
      print('Error listing backups: $e');
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
      print('Error deleting backup: $e');
      return false;
    }
  }

  /// الحصول على مسار ملف قاعدة البيانات
  Future<File> _getDatabaseFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/newmarket.db');
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
      print('Error cleaning old backups: $e');
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
