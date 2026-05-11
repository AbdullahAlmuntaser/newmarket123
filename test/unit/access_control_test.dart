import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/auth/access_guard.dart';
import 'package:supermarket/core/auth/user_role.dart';

void main() {
  test('Access Control Logic Verification', () {
    bool checkAccess(String location, String roleName) {
      return AccessGuard.canAccess(location, UserRole.fromString(roleName));
    }

    // Admin Access
    expect(checkAccess('/reports/sales', 'admin'), isTrue);
    expect(checkAccess('/accounting/coa', 'admin'), isTrue);
    expect(checkAccess('/users', 'admin'), isTrue);
    expect(checkAccess('/settings/backup', 'admin'), isTrue);

    // Manager Access
    expect(checkAccess('/reports/sales', 'manager'), isTrue);
    expect(checkAccess('/inventory/warehouses', 'manager'), isTrue);
    expect(checkAccess('/suppliers', 'manager'), isTrue);
    expect(checkAccess('/accounting/coa', 'manager'), isFalse);
    expect(checkAccess('/users', 'manager'), isFalse);
    expect(checkAccess('/settings/backup', 'manager'), isFalse);

    // Cashier Access
    expect(checkAccess('/sales', 'cashier'), isTrue);
    expect(checkAccess('/customers', 'cashier'), isTrue);
    expect(checkAccess('/reports/sales', 'cashier'), isFalse);
    expect(checkAccess('/accounting/coa', 'cashier'), isFalse);
    expect(checkAccess('/users', 'cashier'), isFalse);
    expect(checkAccess('/pos', 'cashier'), isTrue);
  });
}
