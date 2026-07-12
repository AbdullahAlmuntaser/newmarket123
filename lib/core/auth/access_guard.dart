import 'package:supermarket/core/auth/user_role.dart';

class AccessGuard {
  static bool canAccess(String location, UserRole role) {
    if (role == UserRole.admin) return true;

    if (location == '/login' ||
        location == '/access-denied' ||
        location == '/' ||
        location == '/dashboard' ||
        location == '/pos') {
      return true;
    }

    if (_isAdminOnly(location)) return false;

    if (_isManagerArea(location)) {
      return role == UserRole.manager;
    }

    if (_isCashierArea(location)) {
      return role == UserRole.manager || role == UserRole.cashier;
    }

    return false;
  }

  static bool _isAdminOnly(String location) {
    return location == '/users' ||
        location == '/sync' ||
        location.startsWith('/settings') ||
        location.startsWith('/accounting') ||
        location == '/admin-dashboard';
  }

  static bool _isManagerArea(String location) {
    return location.startsWith('/reports') ||
        location.startsWith('/purchases') ||
        location.startsWith('/approvals') ||
        location.startsWith('/loyalty') ||
        location.startsWith('/promotions') ||
        location.startsWith('/inventory') ||
        location.startsWith('/manufacturing') ||
        location.startsWith('/hr') ||
        location.startsWith('/suppliers') ||
        location.startsWith('/products') ||
        location == '/categories' ||
        location == '/low-stock';
  }

  static bool _isCashierArea(String location) {
    return location.startsWith('/sales') ||
        location.startsWith('/returns') ||
        location.startsWith('/customers');
  }
}
