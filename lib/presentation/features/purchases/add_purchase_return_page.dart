import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class AddPurchaseReturnPage extends StatefulWidget {
  const AddPurchaseReturnPage({super.key});

  @override
  State<AddPurchaseReturnPage> createState() => _AddPurchaseReturnPageState();
}

class _AddPurchaseReturnPageState extends State<AddPurchaseReturnPage> {
  Purchase? _selectedPurchase;
  final List<PurchaseReturnItem> _itemsToReturn = [];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newPurchaseReturn)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: StreamBuilder<List<Purchase>>(
              stream: db.purchasesDao.watchAllPurchases(),
              builder: (context, snapshot) {
                final purchases = snapshot.data ?? [];
                return DropdownButtonFormField<Purchase>(
                  decoration: InputDecoration(labelText: l10n.selectPurchase),
                  items: purchases
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.id)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedPurchase = value),
                );
              },
            ),
          ),
          Expanded(
            child: _selectedPurchase == null
                ? Center(child: Text(l10n.selectAPurchaseToContinue))
                : _buildPurchaseItems(db),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _itemsToReturn.isNotEmpty ? _processReturn : null,
        tooltip: l10n.processReturn,
        child: const Icon(Icons.save),
      ),
    );
  }

  Widget _buildPurchaseItems(AppDatabase db) {
    return StreamBuilder<List<PurchaseItem>>(
      stream: db.purchasesDao.watchPurchaseItems(_selectedPurchase!.id),
      builder: (context, snapshot) {
        final purchaseItems = snapshot.data ?? [];
        return ListView.builder(
          itemCount: purchaseItems.length,
          itemBuilder: (context, index) {
            final item = purchaseItems[index];
            final isSelected = _itemsToReturn.any((i) => i.productId == item.productId);
            return CheckboxListTile(
              title: Text('Product ID: ${item.productId}'), // Replace with product name later
              subtitle: Text('Quantity: ${item.quantity}'),
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    final now = DateTime.now();
                    _itemsToReturn.add(
                      PurchaseReturnItem(
                        id: const Uuid().v4(),
                        purchaseReturnId: '', // Will be updated in _processReturn
                        productId: item.productId,
                        quantity: item.quantity,
                        price: item.price,
                        createdAt: now,
                        updatedAt: now,
                        syncStatus: 1,
                      ),
                    );
                  } else {
                    _itemsToReturn.removeWhere((i) => i.productId == item.productId);
                  }
                });
              },
            );
          },
        );
      },
    );
  }

  Future<void> _processReturn() async {
    final accountingService = Provider.of<AccountingService>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    final totalReturnedAmount = _itemsToReturn.fold(0.0, (sum, item) => sum + (item.quantity * item.price));
    final now = DateTime.now();
    final returnId = const Uuid().v4();

    final newPurchaseReturn = PurchaseReturn(
      id: returnId,
      purchaseId: _selectedPurchase!.id,
      amountReturned: totalReturnedAmount,
      createdAt: now,
      updatedAt: now,
      syncStatus: 1,
    );

    // Update the purchaseReturnId in each item
    final finalItems = _itemsToReturn.map((item) => item.copyWith(purchaseReturnId: returnId)).toList();

    try {
      await accountingService.postPurchaseReturn(newPurchaseReturn, finalItems);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.returnProcessedSuccessfully)));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
