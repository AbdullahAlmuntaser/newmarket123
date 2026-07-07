import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

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
                  const Icon(
                    Icons.business_center_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noCostCentersFound,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        _showAddCostCenterDialog(context, provider),
                    child: Text(l10n.add),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: costCenters.length,
            itemBuilder: (context, index) {
              final cc = costCenters[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.business_center)),
                title: Text(cc.name),
                subtitle: Text(cc.code),
                trailing: Text(
                  cc.code,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddCostCenterDialog(
    BuildContext context,
    AccountingProvider provider,
  ) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مركز تكلفة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'الكود'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.addCostCenter(
                name: nameController.text,
                code: codeController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
