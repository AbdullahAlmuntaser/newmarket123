import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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

  /// Session timeout duration - configurable per deployment
  static Duration sessionTimeout = const Duration(hours: 8);

  /// Maximum failed login attempts before lockout
  static const int maxLoginAttempts = 5;

  /// Lockout duration after max failed attempts
  static Duration lockoutDuration = const Duration(minutes: 15);

  /// WARNING: This flag is ONLY for unit tests. In release builds, this is
  /// always false regardless of what is set here.
  static bool useFakeKeyForTesting = false;

  SecurityService(this.db);

  Future<void> dispose() async {}

  // ==================== PASSWORD HASHING (BCrypt) ====================

  /// Hash password using BCrypt with 12 rounds (OWASP recommended)
  String hashPassword(String password, String salt) {
    return BCrypt.hashpw(password, salt);
  }

  /// Generate a cryptographically secure salt for BCrypt
  String generateSalt() => BCrypt.gensalt();

  /// Verify password against BCrypt hash
  bool verifyPassword(String password, String salt, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (_) {
      // Fallback for legacy SHA-256 hashes during migration
      return _verifyLegacyPassword(password, salt, hash);
    }
  }

  /// Legacy SHA-256 verification for backward compatibility during migration
  bool _verifyLegacyPassword(String password, String salt, String hash) {
    final salted = '$_saltPrefix:$salt:$password';
    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);
    return digest.toString() == hash;
  }

  /// Check if a hash is a BCrypt hash (starts with $2a$, $2b$, or $2y$)
  bool _isBcryptHash(String hash) {
    return hash.startsWith('\$2a\$') || hash.startsWith('\$2b\$') || hash.startsWith('\$2y\$');
  }

  /// Migrate a user's password from SHA-256 to BCrypt
  Future<void> migratePasswordToBcrypt(String userId, String plainPassword) async {
    final newSalt = generateSalt();
    final newHash = hashPassword(plainPassword, newSalt);
    await (db.update(db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        passwordHash: Value(newHash),
        passwordSalt: Value(newSalt),
      ),
    );
  }

  // ==================== AUTHENTICATION ====================

  Future<UserSession?> login(String username, String password) async {
    final user = await (db.select(db.users)
          ..where((u) => u.username.equals(username)))
        .getSingleOrNull();
    if (user == null) return null;

    // Check for account lockout
    final isLocked = await _isAccountLocked(user.id);
    if (isLocked) {
      throw Exception('الحساب مقفل مؤقتاً بسبب محاولات دخول كثيرة. يرجى المحاولة بعد ${lockoutDuration.inMinutes} دقيقة.');
    }

    final bool passwordValid;
    if (user.passwordHash != null && user.passwordSalt != null) {
      passwordValid =
          verifyPassword(password, user.passwordSalt!, user.passwordHash!);
      // Auto-migrate legacy SHA-256 hashes to BCrypt on successful login
      if (passwordValid && !_isBcryptHash(user.passwordHash!)) {
        await migratePasswordToBcrypt(user.id, password);
      }
    } else {
      // No password hash set — try legacy SHA-256 verification
      passwordValid = _verifyLegacyPassword(password, '', user.password);
      if (passwordValid) {
        // Auto-migrate to BCrypt on successful legacy login
        await migratePasswordToBcrypt(user.id, password);
      }
    }

    if (!passwordValid) {
      await _recordFailedLogin(user.id);
      return null;
    }

    // Clear failed login attempts on successful login
    await _clearFailedLoginAttempts(user.id);

    final token = const Uuid().v4();
    final expiresAt = DateTime.now().add(sessionTimeout);
    final loginAt = DateTime.now();

    // Use raw SQL since user_sessions is created via migration
    await db.customStatement(
      'DELETE FROM user_sessions WHERE user_id = ?',
      [user.id],
    );
    await db.customStatement(
      'INSERT INTO user_sessions (id, user_id, token, login_at, expires_at, is_active) VALUES (?, ?, ?, ?, ?, 1)',
      [
        const Uuid().v4(),
        user.id,
        token,
        loginAt.toIso8601String(),
        expiresAt.toIso8601String()
      ],
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

  // ==================== ACCOUNT LOCKOUT ====================

  Future<void> _recordFailedLogin(String userId) async {
    try {
      await db.customStatement(
        'INSERT INTO login_attempts (id, user_id, attempted_at, success) VALUES (?, ?, ?, 0)',
        [const Uuid().v4(), userId, DateTime.now().toIso8601String()],
      );
    } catch (_) {
      // Table might not exist yet, ignore
    }
  }

  Future<void> _clearFailedLoginAttempts(String userId) async {
    try {
      await db.customStatement(
        'DELETE FROM login_attempts WHERE user_id = ? AND success = 0',
        [userId],
      );
    } catch (_) {
      // Table might not exist yet, ignore
    }
  }

  Future<bool> _isAccountLocked(String userId) async {
    try {
      final cutoff = DateTime.now().subtract(lockoutDuration).toIso8601String();
      final result = await db.customSelect(
        'SELECT COUNT(*) as attempt_count FROM login_attempts '
        'WHERE user_id = ? AND success = 0 AND attempted_at >= ?',
        variables: [Variable(userId), Variable(cutoff)],
      ).getSingleOrNull();
      final count = result?.data['attempt_count'] ?? 0;
      return count >= maxLoginAttempts;
    } catch (_) {
      return false;
    }
  }

  // ==================== SESSION VALIDATION ====================

  /// Validate session and check for timeout
  Future<UserSession?> validateSession(String token) async {
    try {
      final rows = await db.customSelect(
        'SELECT us.user_id, us.token, us.login_at, us.expires_at, '
        'u.username, u.role, u.full_name '
        'FROM user_sessions us JOIN users u ON us.user_id = u.id '
        'WHERE us.token = ? AND us.expires_at >= ? AND us.is_active = 1',
        variables: [
          Variable(token),
          Variable(DateTime.now().toIso8601String())
        ],
      ).get();

      if (rows.isEmpty) return null;
      final row = rows.first.data;

      final session = UserSession(
        userId: row['user_id'],
        username: row['username'],
        role: row['role'],
        fullName: (row['full_name'] ?? row['username']) as String,
        token: row['token'],
        loginAt: DateTime.parse(row['login_at']),
        expiresAt: DateTime.parse(row['expires_at']),
      );

      // Check if session has expired
      if (session.isExpired) {
        await logout(token);
        return null;
      }

      return session;
    } catch (_) {
      return null;
    }
  }

  /// Refresh session expiry (extend session on activity)
  Future<void> refreshSession(String token) async {
    final newExpiry = DateTime.now().add(sessionTimeout);
    await db.customStatement(
      'UPDATE user_sessions SET expires_at = ? WHERE token = ? AND is_active = 1',
      [newExpiry.toIso8601String(), token],
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
    // NEVER allow fake key in release builds
    if (useFakeKeyForTesting && kReleaseMode) {
      throw Exception(
          'SECURITY VIOLATION: useFakeKeyForTesting is true in a release build. '
          'This must never happen in production.');
    }
    if (useFakeKeyForTesting) {
      return 'test_encryption_key_for_unit_tests_32_chars_';
    }
    try {
      String? key = await _storage.read(key: _dbKeyName);
      if (key == null || key.isEmpty) {
        key = _generateSecureKey();
        await _storage.write(key: _dbKeyName, value: key);
        final verify = await _storage.read(key: _dbKeyName);
        if (verify == null || verify.isEmpty || verify != key) {
          debugPrint('SECURITY: FlutterSecureStorage write verification failed.');
          throw Exception(
              'CRITICAL: FlutterSecureStorage failed to persist the encryption key. '
              'The app cannot guarantee data encryption safety. '
              'Please reinstall the app or check device storage.');
        }
      }
      return key;
    } catch (e) {
      debugPrint('SECURITY: FlutterSecureStorage error: $e');
      if (e.toString().contains('CRITICAL')) rethrow;
      throw Exception(
          'CRITICAL: Cannot access encryption key from secure storage. '
          'The app cannot safely open the encrypted database. '
          'Please reinstall the app. Original error: $e');
    }
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
