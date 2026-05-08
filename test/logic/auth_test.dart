import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/auth/user_role.dart';

void main() {
  group('UserRole', () {
    test('fromString parses admin correctly', () {
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      expect(UserRole.fromString('ADMIN'), equals(UserRole.admin));
      expect(UserRole.fromString('Admin'), equals(UserRole.admin));
    });

    test('fromString parses manager correctly', () {
      expect(UserRole.fromString('manager'), equals(UserRole.manager));
      expect(UserRole.fromString('MANAGER'), equals(UserRole.manager));
      expect(UserRole.fromString('Manager'), equals(UserRole.manager));
    });

    test('fromString defaults to cashier for unknown roles', () {
      expect(UserRole.fromString('cashier'), equals(UserRole.cashier));
      expect(UserRole.fromString('unknown'), equals(UserRole.cashier));
      expect(UserRole.fromString(''), equals(UserRole.cashier));
      expect(UserRole.fromString('viewer'), equals(UserRole.cashier));
    });
  });

  group('UserRole Permissions', () {
    group('Admin permissions', () {
      test('can access reports', () {
        expect(UserRole.admin.canAccessReports, isTrue);
      });

      test('can access accounting', () {
        expect(UserRole.admin.canAccessAccounting, isTrue);
      });

      test('can access admin settings', () {
        expect(UserRole.admin.canAccessAdminSettings, isTrue);
      });
    });

    group('Manager permissions', () {
      test('can access reports', () {
        expect(UserRole.manager.canAccessReports, isTrue);
      });

      test('can access accounting', () {
        expect(UserRole.manager.canAccessAccounting, isTrue);
      });

      test('cannot access admin settings', () {
        expect(UserRole.manager.canAccessAdminSettings, isFalse);
      });
    });

    group('Cashier permissions', () {
      test('cannot access reports', () {
        expect(UserRole.cashier.canAccessReports, isFalse);
      });

      test('cannot access accounting', () {
        expect(UserRole.cashier.canAccessAccounting, isFalse);
      });

      test('cannot access admin settings', () {
        expect(UserRole.cashier.canAccessAdminSettings, isFalse);
      });
    });
  });

  group('Access Control Logic', () {
    bool checkAccess(String location, String roleName) {
      final role = UserRole.fromString(roleName);

      if (location.startsWith('/reports') && !role.canAccessReports) {
        return false;
      }
      if (location.startsWith('/accounting') && !role.canAccessAccounting) {
        return false;
      }
      if ((location == '/users' ||
              location.startsWith('/settings') ||
              location == '/sync') &&
          !role.canAccessAdminSettings) {
        return false;
      }

      return true;
    }

    test('Admin can access all locations', () {
      expect(checkAccess('/reports/sales', 'admin'), isTrue);
      expect(checkAccess('/reports/inventory', 'admin'), isTrue);
      expect(checkAccess('/accounting/coa', 'admin'), isTrue);
      expect(checkAccess('/accounting/journal', 'admin'), isTrue);
      expect(checkAccess('/users', 'admin'), isTrue);
      expect(checkAccess('/settings/backup', 'admin'), isTrue);
      expect(checkAccess('/sync', 'admin'), isTrue);
      expect(checkAccess('/pos', 'admin'), isTrue);
    });

    test('Manager can access reports and accounting but not admin settings', () {
      expect(checkAccess('/reports/sales', 'manager'), isTrue);
      expect(checkAccess('/reports/inventory', 'manager'), isTrue);
      expect(checkAccess('/accounting/coa', 'manager'), isTrue);
      expect(checkAccess('/accounting/journal', 'manager'), isTrue);
      expect(checkAccess('/pos', 'manager'), isTrue);
      expect(checkAccess('/users', 'manager'), isFalse);
      expect(checkAccess('/settings/backup', 'manager'), isFalse);
      expect(checkAccess('/sync', 'manager'), isFalse);
    });

    test('Cashier can only access POS', () {
      expect(checkAccess('/pos', 'cashier'), isTrue);
      expect(checkAccess('/reports/sales', 'cashier'), isFalse);
      expect(checkAccess('/accounting/coa', 'cashier'), isFalse);
      expect(checkAccess('/users', 'cashier'), isFalse);
      expect(checkAccess('/settings/backup', 'cashier'), isFalse);
    });

    test('Access check is case-insensitive', () {
      expect(checkAccess('/pos', 'admin'), isTrue);
      expect(checkAccess('/pos', 'ADMIN'), isTrue);
      expect(checkAccess('/pos', 'Admin'), isTrue);
    });
  });
}
