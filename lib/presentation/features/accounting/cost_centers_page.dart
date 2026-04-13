import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class CostCentersPage extends StatelessWidget {
  const CostCentersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<AccountingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.costCenters),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCostCenterDialog(context, provider),
            tooltip: l10n.add,
          ),
        ],
      ),
      body: StreamBuilder<List<CostCenter>>(
        stream: provider.watchCostCenters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final costCenters = snapshot.data ?? [];
          if (costCenters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business_center_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.noCostCentersFound, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddCostCenterDialog(context, provider),
                    child: Text(l10n.addCostCenter),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: costCenters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cc = costCenters[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withAlpha(50)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(cc.code, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                  ),
                  title: Text(cc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(cc.code),
                  trailing: Switch(
                    value: cc.isActive,
                    onChanged: (val) => provider.toggleCostCenterStatus(cc),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddCostCenterDialog(BuildContext context, AccountingProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addCostCenter),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: InputDecoration(labelText: l10n.code, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.name, border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                provider.addCostCenter(code: codeController.text, name: nameController.text);
                Navigator.pop(context);
              }
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }
}
