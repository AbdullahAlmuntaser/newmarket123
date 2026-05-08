import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart'
    hide Permission;
import 'package:permission_handler/permission_handler.dart';

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  Future<File?> createBackupExternal() async {
    // طلب الإذن للوصول للتخزين
    if (await Permission.storage.request().isGranted) {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

      // مسار خارجي عام (مثال)
      final externalDir = Directory('/storage/emulated/0/Download');
      final backupFile = File(p.join(externalDir.path,
          'backup_${DateTime.now().millisecondsSinceEpoch}.sqlite'));

      return await dbFile.copy(backupFile.path);
    }
    return null;
  }

  Future<File> createBackup() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

    final backupFolder = await getApplicationDocumentsDirectory();
    final backupFile = File(p.join(backupFolder.path,
        'backup_${DateTime.now().millisecondsSinceEpoch}.sqlite'));

    return await dbFile.copy(backupFile.path);
  }

  Future<void> restoreBackup(File backupFile) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

    await backupFile.copy(dbFile.path);
  }
}
