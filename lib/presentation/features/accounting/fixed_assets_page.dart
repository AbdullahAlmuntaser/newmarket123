import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/accounting/asset_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

class FixedAssetsPage extends StatefulWidget {
  const FixedAssetsPage({super.key});

  @override
  State<FixedAssetsPage> createState() => _FixedAssetsPageState();
}

class _FixedAssetsPageState extends State<FixedAssetsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssetProvider>().loadAssets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأصول الثابتة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: () => provider.runDepreciation(),
            tooltip: 'حساب الإهلاك الشهري',
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.assets.length,
              itemBuilder: (context, index) {
                final asset = provider.assets[index];
                final bookValue = asset.cost - asset.accumulatedDepreciation;
                return ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: Text(asset.name),
                  subtitle: Text('التكلفة: ${asset.cost} | الإهلاك المتراكم: ${asset.accumulatedDepreciation.toStringAsFixed(2)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('القيمة الدفترية', style: Theme.of(context).textTheme.bodySmall),
                      Text(bookValue.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAssetDialog(context, provider),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddAssetDialog(BuildContext context, AssetProvider provider) {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    final lifeController = TextEditingController();
    final salvageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة أصل جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الأصل')),
            TextField(controller: costController, decoration: const InputDecoration(labelText: 'التكلفة'), keyboardType: TextInputType.number),
            TextField(controller: lifeController, decoration: const InputDecoration(labelText: 'العمر الافتراضي (سنوات)'), keyboardType: TextInputType.number),
            TextField(controller: salvageController, decoration: const InputDecoration(labelText: 'قيمة الخردة'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              provider.addAsset(FixedAssetsCompanion.insert(
                id: Value(const Uuid().v4()),
                name: nameController.text,
                cost: double.tryParse(costController.text) ?? 0.0,
                usefulLifeYears: int.tryParse(lifeController.text) ?? 5,
                salvageValue: Value(double.tryParse(salvageController.text) ?? 0.0),
                purchaseDate: DateTime.now(),
              ));
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
