import 'package:supermarket/core/auth/user_role.dart';

class AccessGuard {
  static bool canAccess(String location, UserRole role) {
    if (location.startsWith('/reports') && !role.canAccessReports) return false;
    if (location.startsWith('/accounting') && !role.canAccessAccounting) {
      return false;
    }
    if ((location == '/users' ||
            location.startsWith('/settings') ||
            location == '/sync') &&
        !role.canAccessAdminSettings) return false;
    return true;
  }
}
