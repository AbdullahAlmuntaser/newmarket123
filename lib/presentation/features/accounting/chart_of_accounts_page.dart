import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class ChartOfAccountsPage extends StatelessWidget {
  const ChartOfAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
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
                  const Text('No accounts found.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.seedAccounts(),
                    child: const Text('Seed Default Accounts'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getTypeColor(account.type),
                  child: Text(
                    account.code[0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(account.name),
                subtitle: Text(
                  '${account.code} • ${_getTypeLabel(context, account.type)}',
                ),
                trailing: Text(
                  account.balance.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: account.balance < 0 ? Colors.red : Colors.green,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        child: const Icon(Icons.add),
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
