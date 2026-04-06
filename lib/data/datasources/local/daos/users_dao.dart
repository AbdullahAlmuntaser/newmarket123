import 'package:drift/drift.dart';
import '../app_database.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users, Permissions, RolePermissions])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<List<User>> getAllUsers() => select(users).get();
  Stream<List<User>> watchAllUsers() => select(users).watch();
  Future<int> addUser(UsersCompanion user) => into(users).insert(user);
  Future<bool> updateUser(User user) => update(users).replace(user);
  Future<int> deleteUser(User user) => delete(users).delete(user);

  // Auth
  Future<User?> authenticate(String username, String password) async {
    return (select(users)
          ..where((u) => u.username.equals(username) & u.password.equals(password)))
        .getSingleOrNull();
  }

  // Permission Checks
  Future<bool> hasPermission(String username, String permissionCode) async {
    final user = await (select(users)..where((u) => u.username.equals(username)))
        .getSingleOrNull();
    if (user == null) return false;
    if (user.role == 'ADMIN') return true; // Admin has all permissions

    final query = select(rolePermissions)
      ..where(
        (rp) =>
            rp.role.equals(user.role) &
            rp.permissionCode.equals(permissionCode),
      );
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // Permission Management
  Future<void> addPermission(PermissionsCompanion permission) =>
      into(permissions).insertOnConflictUpdate(permission);

  Future<void> assignPermissionToRole(String role, String permissionCode) =>
      into(rolePermissions).insert(
        RolePermissionsCompanion.insert(
          role: role,
          permissionCode: permissionCode,
        ),
      );

  Future<List<String>> getRolePermissions(String role) async {
    final query = select(rolePermissions)..where((rp) => rp.role.equals(role));
    final rows = await query.get();
    return rows.map((r) => r.permissionCode).toList();
  }

  Future<void> removePermissionFromRole(String role, String permissionCode) {
    return (delete(rolePermissions)
          ..where(
            (rp) =>
                rp.role.equals(role) &
                rp.permissionCode.equals(permissionCode),
          ))
        .go();
  }
}
