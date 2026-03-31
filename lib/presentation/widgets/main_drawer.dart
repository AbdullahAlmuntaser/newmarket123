import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/network/sync_service.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context);
    final syncService = Provider.of<SyncService>(context);
    final isAdmin = authProvider.currentUser?.role == 'admin';

    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        authProvider.currentUser?.fullName ?? 'User',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      Text(
                        authProvider.currentUser?.role ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: Text(l10n.dashboard),
                  onTap: () => context.go('/'),
                ),
                ListTile(
                  leading: const Icon(Icons.point_of_sale),
                  title: Text(l10n.pos),
                  onTap: () => context.go('/pos'),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.sales),
                  onTap: () => context.go('/sales'),
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_return),
                  title: Text(l10n.returns),
                  onTap: () => context.go('/returns'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(l10n.products),
                  onTap: () => context.go('/products'),
                ),
                ListTile(
                  leading: const Icon(Icons.category),
                  title: Text(l10n.categories),
                  onTap: () => context.go('/categories'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.shopping_cart),
                  title: Text(l10n.purchases),
                  onTap: () => context.go('/purchases'),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(l10n.customers),
                  onTap: () => context.go('/customers'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: Text(l10n.suppliers),
                  onTap: () => context.go('/suppliers'),
                ),
                const Divider(),
                ExpansionTile(
                  leading: const Icon(Icons.account_balance),
                  title: Text(l10n.accounting),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_tree),
                      title: Text(l10n.chartOfAccounts),
                      onTap: () => context.go('/accounting/coa'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: Text(l10n.generalLedger),
                      onTap: () => context.go('/accounting/general-ledger'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.balance),
                      title: Text(l10n.trialBalance),
                      onTap: () => context.go('/accounting/trial-balance'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.money_off),
                      title: Text(l10n.expenses),
                      onTap: () => context.go('/accounting/expenses'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: Text(l10n.manualJournalEntries),
                      onTap: () => context.go('/accounting/manual-entry'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: Text(l10n.reconciliation),
                      onTap: () => context.go('/accounting/reconciliation'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(l10n.shiftManagement),
                      onTap: () => context.go('/accounting/shifts'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.payments),
                      title: Text(l10n.cashFlow),
                      onTap: () => context.go('/accounting/cash-flow'),
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.bar_chart),
                  title: Text(l10n.reports),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inventory),
                      title: Text(l10n.inventoryReports),
                      onTap: () => context.go('/reports'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt),
                      title: Text(l10n.vatReturn),
                      onTap: () => context.go('/reports/vat'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.history_edu),
                      title: Text(l10n.auditLog),
                      onTap: () => context.go('/reports/audit'),
                    ),
                  ],
                ),
                ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(l10n.thermalPrinting),
                  onTap: () => context.go('/settings/printer'),
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('النسخ الاحتياطي'),
                  onTap: () => context.go('/settings/backup'),
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.manage_accounts),
                    title: const Text('إدارة المستخدمين'),
                    onTap: () => context.go('/users'),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    l10n.logout,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    authProvider.logout();
                    context.go('/login');
                  },
                ),
              ],
            ),
          ),
          _buildSyncStatus(context, syncService),
        ],
      ),
    );
  }

  Widget _buildSyncStatus(BuildContext context, SyncService syncService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(13),
        border: const Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: syncService.isSyncing,
        builder: (context, isSyncing, child) {
          return Row(
            children: [
              Icon(
                Icons.sync,
                size: 16,
                color: isSyncing ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                isSyncing ? 'جاري المزامنة...' : 'تمت المزامنة',
                style: TextStyle(
                  fontSize: 12,
                  color: isSyncing ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (!isSyncing)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () => syncService.syncAll(),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              if (isSyncing)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          );
        },
      ),
    );
  }
}
