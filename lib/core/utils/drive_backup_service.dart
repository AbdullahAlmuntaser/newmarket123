import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/logger.dart';

class DriveBackupService {
  final AppDatabase db;
  GoogleSignIn? _googleSignIn;
  bool _isAuthenticated = false;
  String? _userEmail;

  DriveBackupService(this.db);

  Future<bool> signIn() async {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: ['https://www.googleapis.com/auth/drive.file'],
      );

      final account = await _googleSignIn!.signIn();
      if (account != null) {
        _isAuthenticated = true;
        _userEmail = account.email;
        AppLogger.info('Signed in to Google Drive as: $_userEmail');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to sign in to Google Drive', error: e);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _isAuthenticated = false;
      _userEmail = null;
      AppLogger.info('Signed out from Google Drive');
    } catch (e) {
      AppLogger.error('Failed to sign out from Google Drive', error: e);
    }
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;

  Future<String?> createCloudBackup() async {
    if (!_isAuthenticated) {
      final signedIn = await signIn();
      if (!signedIn) return null;
    }

    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'supermarket_backup_$timestamp.sqlite';

      AppLogger.info('Cloud backup prepared: $fileName');
      return 'backup_prepared_$fileName';
    } catch (e) {
      AppLogger.error('Failed to prepare cloud backup', error: e);
      return null;
    }
  }

  Future<List<CloudBackupInfo>> listCloudBackups() async {
    if (!_isAuthenticated) return [];
    return [];
  }

  Future<bool> deleteCloudBackup(String fileId) async {
    if (!_isAuthenticated) return false;
    return false;
  }
}

class CloudBackupInfo {
  final String id;
  final String name;
  final DateTime createdTime;
  final String size;

  CloudBackupInfo({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.size,
  });
}