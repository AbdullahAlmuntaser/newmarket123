import 'package:flutter/material.dart';
import '../../data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;

class AuthProvider with ChangeNotifier {
  final AppDatabase db;
  User? _currentUser;

  AuthProvider(this.db);

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';

  Future<bool> login(String username, String password) async {
    // In a real app, use password hashing (e.g. BCrypt)
    final user =
        await (db.select(db.users)..where(
              (u) => u.username.equals(username) & u.password.equals(password),
            ))
            .getSingleOrNull();

    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // Initial seed user
  Future<void> seedAdmin() async {
    final count = await db.select(db.users).get();
    if (count.isEmpty) {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              username: 'admin',
              password: '123', // Demo password
              role: 'admin',
              fullName: 'System Admin',
            ),
          );
    }
  }
}
