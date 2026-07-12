import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../data/datasources/local/app_database.dart';
import '../services/permission_service.dart';

class AuthProvider with ChangeNotifier {
  final AppDatabase db;
  final PermissionService permissionsService;
  User? _currentUser;

  AuthProvider(this.db, this.permissionsService);

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role.toLowerCase() == 'admin';
  bool get isManager =>
      isAdmin || _currentUser?.role.toLowerCase() == 'manager';
  bool get isCashier =>
      isManager || _currentUser?.role.toLowerCase() == 'cashier';

  Future<bool> login(String username, String password) async {
    final user = await (db.select(
      db.users,
    )..where((u) => u.username.equals(username)))
        .getSingleOrNull();

    if (user != null && BCrypt.checkpw(password, user.password)) {
      _currentUser = user;
      // Note: New PermissionService doesn't need init, it checks DB directly
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> hasUsers() async {
    final users = await db.select(db.users).get();
    return users.isNotEmpty;
  }

  Future<void> createInitialAdmin({
    required String username,
    required String password,
    required String fullName,
  }) async {
    if (await hasUsers()) {
      throw Exception('Initial admin user already exists.');
    }

    if (username.trim().isEmpty) {
      throw Exception('Admin username is required.');
    }

    if (password.length < 8) {
      throw Exception('Admin password must be at least 8 characters.');
    }

    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
    await db.into(db.users).insert(
          UsersCompanion.insert(
            username: username.trim(),
            password: hashedPassword,
            role: 'admin',
            fullName:
                fullName.trim().isEmpty ? 'System Admin' : fullName.trim(),
          ),
        );

    await db.seedSecurityData();
  }

  // Backward-compatible entry point for existing callers/tests.
  // It now only ensures security metadata and never creates a weak default user.
  Future<void> seedAdmin() async {
    await db.seedSecurityData();
  }
}
