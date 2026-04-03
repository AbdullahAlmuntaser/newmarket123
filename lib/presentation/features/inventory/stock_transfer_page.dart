import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/inventory/stock_transfer_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class StockTransferPage extends StatefulWidget {
  const StockTransferPage({super.key});

  @override
  State<StockTransferPage> createState() => _StockTransferPageState();
}

class _StockTransferPageState extends State<StockTransferPage> {
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockTransferProvider>().loadWarehouses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockTransferProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('تحويل مخزني')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildWarehouseSelectors(provider, l10n),
                const Divider(),
                Expanded(child: _buildTransferItemsList(provider)),
                _buildBottomActions(provider, l10n),
              ],
            ),
      floatingActionButton: provider.selectedFromWarehouseId != null
          ? FloatingActionButton(
              onPressed: () => _showAddItemDialog(context, provider),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildWarehouseSelectors(StockTransferProvider provider, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: provider.selectedFromWarehouseId,
            decoration: const InputDecoration(labelText: 'من مستودع'),
            items: provider.warehouses
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: (val) => provider.setFromWarehouse(val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: provider.selectedToWarehouseId,
            decoration: const InputDecoration(labelText: 'إلى مستودع'),
            items: provider.warehouses
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: (val) => provider.setToWarehouse(val),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferItemsList(StockTransferProvider provider) {
    if (provider.transferItems.isEmpty) {
      return const Center(child: Text('لا يوجد أصناف مضافة للتحويل'));
    }

    return ListView.builder(
      itemCount: provider.transferItems.length,
      itemBuilder: (context, index) {
        final item = provider.transferItems[index];
        return ListTile(
          title: FutureBuilder<Product?>(
            future: (context.read<AppDatabase>().select(context.read<AppDatabase>().products)
                  ..where((t) => t.id.equals(item.productId)))
                .getSingleOrNull(),
            builder: (context, snapshot) => Text(snapshot.data?.name ?? 'Loading...'),
          ),
          subtitle: Text('الكمية: ${item.quantity}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => provider.removeTransferItem(item.batchId),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(StockTransferProvider provider, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: provider.transferItems.isEmpty || provider.selectedToWarehouseId == null
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await provider.submitTransfer(_noteController.text);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('تم التحويل بنجاح')),
                        );
                        _noteController.clear();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
              child: const Text('تأكيد التحويل'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, StockTransferProvider provider) {
    final db = context.read<AppDatabase>();
    final quantityController = TextEditingController();
    ProductBatch? selectedBatch;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة صنف للتحويل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ProductBatch>(
                initialValue: selectedBatch,
                decoration: const InputDecoration(labelText: 'اختر الدفعة/المنتج'),
                items: provider.availableBatches.map((b) {
                  return DropdownMenuItem(
                    value: b,
                    child: FutureBuilder<Product?>(
                      future: (db.select(db.products)..where((t) => t.id.equals(b.productId))).getSingleOrNull(),
                      builder: (context, snapshot) => Text('${snapshot.data?.name} (Batch: ${b.batchNumber}, Qty: ${b.quantity})'),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedBatch = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(quantityController.text);
                if (selectedBatch != null && qty != null && qty > 0) {
                  provider.addTransferItem(selectedBatch!, qty);
                  Navigator.pop(context);
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}
