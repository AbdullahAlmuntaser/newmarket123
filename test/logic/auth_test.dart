import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/auth/access_guard.dart';
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

      test('cannot access accounting', () {
        expect(UserRole.manager.canAccessAccounting, isFalse);
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
      return AccessGuard.canAccess(location, UserRole.fromString(roleName));
    }

    test('Admin can access all major areas', () {
      expect(checkAccess('/reports/sales', 'admin'), isTrue);
      expect(checkAccess('/accounting/coa', 'admin'), isTrue);
      expect(checkAccess('/users', 'admin'), isTrue);
      expect(checkAccess('/settings/backup', 'admin'), isTrue);
      expect(checkAccess('/sync', 'admin'), isTrue);
      expect(checkAccess('/pos', 'admin'), isTrue);
      expect(checkAccess('/hr/employees', 'admin'), isTrue);
    });

    test('Manager can access operational areas but not admin-only areas', () {
      expect(checkAccess('/reports/sales', 'manager'), isTrue);
      expect(checkAccess('/purchases', 'manager'), isTrue);
      expect(checkAccess('/inventory/stock-take', 'manager'), isTrue);
      expect(checkAccess('/suppliers', 'manager'), isTrue);
      expect(checkAccess('/pos', 'manager'), isTrue);
      expect(checkAccess('/accounting/coa', 'manager'), isFalse);
      expect(checkAccess('/users', 'manager'), isFalse);
      expect(checkAccess('/settings/backup', 'manager'), isFalse);
      expect(checkAccess('/sync', 'manager'), isFalse);
    });

    test('Cashier can access cashier areas only', () {
      expect(checkAccess('/pos', 'cashier'), isTrue);
      expect(checkAccess('/sales', 'cashier'), isTrue);
      expect(checkAccess('/returns/new', 'cashier'), isTrue);
      expect(checkAccess('/customers', 'cashier'), isTrue);
      expect(checkAccess('/reports/sales', 'cashier'), isFalse);
      expect(checkAccess('/accounting/coa', 'cashier'), isFalse);
      expect(checkAccess('/purchases', 'cashier'), isFalse);
      expect(checkAccess('/users', 'cashier'), isFalse);
    });

    test('Access check is case-insensitive', () {
      expect(checkAccess('/pos', 'admin'), isTrue);
      expect(checkAccess('/pos', 'ADMIN'), isTrue);
      expect(checkAccess('/pos', 'Admin'), isTrue);
    });
  });
}
