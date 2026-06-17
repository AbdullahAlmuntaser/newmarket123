import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

class UserSession {
  final String userId;
  final String username;
  final String role;
  final String fullName;
  final String token;
  final DateTime loginAt;
  final DateTime expiresAt;

  UserSession({
    required this.userId,
    required this.username,
    required this.role,
    required this.fullName,
    required this.token,
    required this.loginAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'role': role,
        'fullName': fullName,
        'token': token,
        'loginAt': loginAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        userId: json['userId'],
        username: json['username'],
        role: json['role'],
        fullName: json['fullName'],
        token: json['token'],
        loginAt: DateTime.parse(json['loginAt']),
        expiresAt: DateTime.parse(json['expiresAt']),
      );
}

class SecurityService {
  final AppDatabase db;
  static const String _saltPrefix = 'SYS_MARKET_v1';
  static const _storage = FlutterSecureStorage();
  static const _dbKeyName = 'db_encryption_key';

  static bool useFakeKeyForTesting = false;

  SecurityService(this.db);

  Future<void> dispose() async {}

  // ==================== PASSWORD HASHING ====================

  String hashPassword(String password, String salt) {
    final salted = '$_saltPrefix:$salt:$password';
    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String generateSalt() => const Uuid().v4().substring(0, 16);

  bool verifyPassword(String password, String salt, String hash) {
    return hashPassword(password, salt) == hash;
  }

  // ==================== AUTHENTICATION ====================

  Future<UserSession?> login(String username, String password) async {
    final user = await (db.select(db.users)
          ..where((u) => u.username.equals(username)))
        .getSingleOrNull();
    if (user == null) return null;

    final bool passwordValid;
    if (user.passwordHash != null && user.passwordSalt != null) {
      passwordValid =
          verifyPassword(password, user.passwordSalt!, user.passwordHash!);
    } else {
      passwordValid = password == user.password;
    }
    if (!passwordValid) return null;

    final token = const Uuid().v4();
    final expiresAt = DateTime.now().add(const Duration(hours: 8));
    final loginAt = DateTime.now();

    // Use raw SQL since user_sessions is created via migration
    await db.customStatement(
      'DELETE FROM user_sessions WHERE user_id = ?',
      [user.id],
    );
    await db.customStatement(
      'INSERT INTO user_sessions (id, user_id, token, login_at, expires_at, is_active) VALUES (?, ?, ?, ?, ?, 1)',
      [const Uuid().v4(), user.id, token, loginAt.toIso8601String(), expiresAt.toIso8601String()],
    );

    await _storage.write(key: 'auth_token_${user.id}', value: token);

    return UserSession(
      userId: user.id,
      username: user.username,
      role: user.role,
      fullName: user.fullName,
      token: token,
      loginAt: loginAt,
      expiresAt: expiresAt,
    );
  }

  Future<UserSession?> validateSession(String token) async {
    try {
      final rows = await db.customSelect(
        'SELECT us.user_id, us.token, us.login_at, us.expires_at, '
        'u.username, u.role, u.full_name '
        'FROM user_sessions us JOIN users u ON us.user_id = u.id '
        'WHERE us.token = ? AND us.expires_at >= ? AND us.is_active = 1',
        variables: [Variable(token), Variable(DateTime.now().toIso8601String())],
      ).get();

      if (rows.isEmpty) return null;
      final row = rows.first.data;

      return UserSession(
        userId: row['user_id'],
        username: row['username'],
        role: row['role'],
        fullName: (row['full_name'] ?? row['username']) as String,
        token: row['token'],
        loginAt: DateTime.parse(row['login_at']),
        expiresAt: DateTime.parse(row['expires_at']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> logout(String token) async {
    await db.customStatement(
      'DELETE FROM user_sessions WHERE token = ?',
      [token],
    );
  }

  Future<void> logoutAllSessions(String userId) async {
    await db.customStatement(
      'DELETE FROM user_sessions WHERE user_id = ?',
      [userId],
    );
  }

  // ==================== PERMISSION CHECKING ====================

  static const roleHierarchy = ['VIEWER', 'CASHIER', 'MANAGER', 'ADMIN'];

  bool hasPermission(String userRole, String requiredRole) {
    final userLevel = roleHierarchy.indexOf(userRole);
    final requiredLevel = roleHierarchy.indexOf(requiredRole);
    if (userLevel == -1 || requiredLevel == -1) return false;
    return userLevel >= requiredLevel;
  }

  void requireRole(String userRole, String requiredRole) {
    if (!hasPermission(userRole, requiredRole)) {
      throw Exception('ليس لديك صلاحية كافية للقيام بهذه العملية');
    }
  }

  void requireOneOf(String userRole, List<String> allowedRoles) {
    for (final role in allowedRoles) {
      if (hasPermission(userRole, role)) return;
    }
    throw Exception('ليس لديك صلاحية كافية');
  }

  // ==================== DATA ENCRYPTION ====================

  static Future<String> getDatabaseKey() async {
    if (useFakeKeyForTesting) {
      return 'test_encryption_key_for_unit_tests_32_chars_';
    }
    String? key = await _storage.read(key: _dbKeyName);
    if (key == null) {
      key = _generateSecureKey();
      await _storage.write(key: _dbKeyName, value: key);
    }
    return key;
  }

  static String _generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  // ==================== BACKUP VALIDATION ====================

  Future<bool> validateBackupIntegrity(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      if (!content.contains('SYS_MARKET_BACKUP_V1')) return false;
      final hashIndex = content.lastIndexOf('--HASH:');
      if (hashIndex == -1) return false;
      final storedHash = content.substring(hashIndex + 7).trim();
      final dataToVerify = content.substring(0, hashIndex);
      final computedHash = sha256.convert(utf8.encode(dataToVerify)).toString();
      return storedHash == computedHash;
    } catch (_) {
      return false;
    }
  }

  Future<String> signBackup(String data) async {
    final hash = sha256.convert(utf8.encode(data)).toString();
    return '$data\n--HASH:$hash';
  }
}
