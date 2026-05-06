enum UserRole {
  admin,
  manager,
  cashier;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      default:
        return UserRole.cashier;
    }
  }

  bool get canAccessReports => this == UserRole.admin || this == UserRole.manager;
  bool get canAccessAccounting => this == UserRole.admin || this == UserRole.manager;
  bool get canAccessAdminSettings => this == UserRole.admin;
}
