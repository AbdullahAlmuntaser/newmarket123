import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/logger.dart';

class AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class DriveBackupService {
  final AppDatabase db;
  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  bool _isAuthenticated = false;
  String? _userEmail;
  static const String _appFolderName = 'SystemMarket Backups';
  DateTime? _lastBackupTime;
  Duration _backupInterval = const Duration(days: 1);

  DriveBackupService(this.db);

  Future<bool> signIn() async {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/drive.file',
          'https://www.googleapis.com/auth/drive.appdata',
        ],
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
      _driveApi = null;
      _isAuthenticated = false;
      _userEmail = null;
      AppLogger.info('Signed out from Google Drive');
    } catch (e) {
      AppLogger.error('Failed to sign out from Google Drive', error: e);
    }
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;

  void setBackupInterval(Duration interval) {
    _backupInterval = interval;
  }

  bool shouldAutoBackup() {
    if (_lastBackupTime == null) return true;
    return DateTime.now().difference(_lastBackupTime!) >= _backupInterval;
  }

  Future<String?> createCloudBackup() async {
    if (!_isAuthenticated) {
      final signedIn = await signIn();
      if (!signedIn) return null;
    }

    if (_driveApi == null) {
      AppLogger.error('Drive API not initialized');
      return null;
    }

    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'systemmarket_backup_$timestamp.db';

      final appFolderId = await _getOrCreateAppFolder();
      if (appFolderId == null) {
        AppLogger.error('Could not find or create app folder');
        return null;
      }

      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = [appFolderId];

      final bytes = await dbFile.readAsBytes();
      final media = drive.Media(Stream.value(bytes), bytes.length);

      final uploadedFile = await _driveApi!.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      _lastBackupTime = DateTime.now();
      AppLogger.info('Cloud backup created: ${uploadedFile.id}');
      return uploadedFile.id;
    } catch (e) {
      AppLogger.error('Failed to create cloud backup', error: e);
      return null;
    }
  }

  Future<String?> _getOrCreateAppFolder() async {
    try {
      final folderList = await _driveApi!.files.list(
        q: "name='$_appFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );

      if (folderList.files!.isNotEmpty) {
        return folderList.files!.first.id;
      }

      final folderMetadata = drive.File()
        ..name = _appFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final folder = await _driveApi!.files.create(folderMetadata);
      return folder.id;
    } catch (e) {
      AppLogger.error('Failed to get or create app folder', error: e);
      return null;
    }
  }

  Future<List<CloudBackupInfo>> listCloudBackups() async {
    if (!_isAuthenticated || _driveApi == null) return [];

    try {
      final appFolderId = await _getOrCreateAppFolder();
      if (appFolderId == null) return [];

      final fileList = await _driveApi!.files.list(
        q: "'$appFolderId' in parents and mimeType='application/octet-stream' and trashed=false",
        orderBy: 'createdTime desc',
      );

      return fileList.files!.map((file) {
        final fileSize = file.size != null ? int.tryParse(file.size.toString()) ?? 0 : 0;
        return CloudBackupInfo(
          id: file.id ?? '',
          name: file.name ?? 'Unknown',
          createdTime: file.createdTime ?? DateTime.now(),
          size: _formatFileSize(fileSize),
        );
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to list cloud backups', error: e);
      return [];
    }
  }

  Future<bool> downloadCloudBackup(String fileId, String localPath) async {
    if (!_isAuthenticated || _driveApi == null) return false;

    try {
      final response = await _driveApi!.files.get(fileId) as drive.Media;

      final file = File(localPath);
      final sink = file.openWrite();
      await sink.addStream(response.stream);
      await sink.close();

      AppLogger.info('Downloaded backup to: $localPath');
      return true;
    } catch (e) {
      AppLogger.error('Failed to download cloud backup', error: e);
      return false;
    }
  }

  Future<bool> deleteCloudBackup(String fileId) async {
    if (!_isAuthenticated || _driveApi == null) return false;

    try {
      await _driveApi!.files.delete(fileId);
      AppLogger.info('Deleted cloud backup: $fileId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete cloud backup', error: e);
      return false;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<bool> restoreFromCloudBackup(String fileId) async {
    if (!_isAuthenticated || _driveApi == null) return false;

    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final tempPath = p.join(dbFolder.path, 'restore_temp.db');

      final success = await downloadCloudBackup(fileId, tempPath);
      if (!success) return false;

      await db.close();

      final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));
      final tempFile = File(tempPath);

      await tempFile.copy(dbFile.path);
      await tempFile.delete();

      AppLogger.info('Backup restored successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to restore from cloud backup', error: e);
      return false;
    }
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