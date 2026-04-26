class PermissionService {
  static const String canViewCost = 'view_cost';
  static const String canDeleteInvoice = 'delete_invoice';

  List<String> _userPermissions = [];

  static final Map<String, List<String>> _rolePermissions = {
    'admin': [canViewCost, canDeleteInvoice, 'manage_users', 'view_reports'],
    'manager': [canViewCost, 'view_reports'],
    'cashier': [],
  };

  PermissionService();

  void init(String? role) {
    _userPermissions = [];
    if (role != null && _rolePermissions.containsKey(role)) {
      _userPermissions.addAll(_rolePermissions[role]!);
    }
  }

  bool hasPermission(String permission) =>
      _userPermissions.contains(permission);
}
