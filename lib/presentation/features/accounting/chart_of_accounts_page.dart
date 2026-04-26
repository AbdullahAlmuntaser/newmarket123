import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class ChartOfAccountsPage extends StatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  State<ChartOfAccountsPage> createState() => _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends State<ChartOfAccountsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountingProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chartOfAccounts),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<GLAccount>>(
        stream: provider.watchAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('لا توجد حسابات.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.seedAccounts(),
                    child: const Text('إنشاء الحسابات الافتراضية'),
                  ),
                ],
              ),
            );
          }

          final filteredAccounts = accounts
              .where(
                (a) =>
                    a.name.contains(_searchQuery) ||
                    a.code.contains(_searchQuery),
              )
              .toList();

          // Group accounts by type
          final Map<String, List<GLAccount>> grouped = {};
          for (var a in filteredAccounts) {
            grouped.putIfAbsent(a.type, () => []).add(a);
          }

          final types = ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'];

          return ListView.builder(
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              final typeAccounts = grouped[type] ?? [];
              if (typeAccounts.isEmpty && _searchQuery.isNotEmpty) {
                return const SizedBox.shrink();
              }

              return ExpansionTile(
                initiallyExpanded: _searchQuery.isNotEmpty,
                title: Text(
                  _getTypeLabel(context, type),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                leading: Icon(Icons.folder, color: _getTypeColor(type)),
                children: typeAccounts
                    .map(
                      (account) =>
                          _buildAccountTile(context, account, provider),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addAccount),
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    GLAccount account,
    AccountingProvider provider,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: account.isHeader
            ? Colors.grey.shade200
            : _getTypeColor(account.type).withAlpha(30),
        child: Text(
          account.code[0],
          style: TextStyle(
            color: _getTypeColor(account.type),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        account.name,
        style: TextStyle(
          fontWeight: account.isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(account.code, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        account.balance.toStringAsFixed(2),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: account.balance < 0 ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ASSET':
        return Colors.blue;
      case 'LIABILITY':
        return Colors.red;
      case 'EQUITY':
        return Colors.orange;
      case 'REVENUE':
        return Colors.green;
      case 'EXPENSE':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 'ASSET':
        return l10n.asset;
      case 'LIABILITY':
        return l10n.liability;
      case 'EQUITY':
        return l10n.equity;
      case 'REVENUE':
        return l10n.revenue;
      case 'EXPENSE':
        return l10n.expense;
      default:
        return type;
    }
  }

  void _showAddAccountDialog(BuildContext context) {
    final provider = context.read<AccountingProvider>();
    final l10n = AppLocalizations.of(context)!;
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    String selectedType = 'ASSET';
    bool isHeader = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(labelText: l10n.accountCode),
                ),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l10n.accountName),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedType = val!),
                  decoration: InputDecoration(labelText: l10n.accountType),
                ),
                SwitchListTile(
                  title: Text(l10n.isHeader),
                  value: isHeader,
                  onChanged: (val) => setState(() => isHeader = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                provider.addAccount(
                  code: codeController.text,
                  name: nameController.text,
                  type: selectedType,
                  isHeader: isHeader,
                );
                Navigator.pop(context);
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }
}
