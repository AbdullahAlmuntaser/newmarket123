import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/auth/user_role.dart';

void main() {
  test('Access Control Logic Verification', () {
    // Testing the logic implemented in appRouter redirect.
    // This simulates different roles and locations to verify redirection.

    bool checkAccess(String location, String roleName) {
      final role = UserRole.fromString(roleName);

      // Simulate the logic from AccessGuard
      if (location.startsWith('/reports') && !role.canAccessReports) {
        return false;
      }
      if (location.startsWith('/accounting') && !role.canAccessAccounting) {
        return false;
      }
      if ((location == '/users' ||
              location.startsWith('/settings') ||
              location == '/sync') &&
          !role.canAccessAdminSettings) return false;

      return true;
    }

    // Admin Access
    expect(checkAccess('/reports/sales', 'admin'), isTrue);
    expect(checkAccess('/accounting/coa', 'admin'), isTrue);
    expect(checkAccess('/users', 'admin'), isTrue);
    expect(checkAccess('/settings/backup', 'admin'), isTrue);

    // Manager Access
    expect(checkAccess('/reports/sales', 'manager'), isTrue);
    expect(checkAccess('/accounting/coa', 'manager'), isTrue);
    expect(checkAccess('/users', 'manager'), isFalse);
    expect(checkAccess('/settings/backup', 'manager'), isFalse);

    // Cashier Access
    expect(checkAccess('/reports/sales', 'cashier'), isFalse);
    expect(checkAccess('/accounting/coa', 'cashier'), isFalse);
    expect(checkAccess('/users', 'cashier'), isFalse);
    expect(checkAccess('/pos', 'cashier'), isTrue); // Should be allowed
  });
}
