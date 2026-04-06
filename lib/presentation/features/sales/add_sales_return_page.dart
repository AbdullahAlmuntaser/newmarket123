import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class AddSalesReturnPage extends StatefulWidget {
  const AddSalesReturnPage({super.key});

  @override
  State<AddSalesReturnPage> createState() => _AddSalesReturnPageState();
}

class _AddSalesReturnPageState extends State<AddSalesReturnPage> {
  Sale? _selectedSale;
  final List<SalesReturnItem> _itemsToReturn = [];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newSalesReturn)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: StreamBuilder<List<Sale>>(
              stream: db.salesDao.watchAllSales(),
              builder: (context, snapshot) {
                final sales = snapshot.data ?? [];
                return DropdownButtonFormField<Sale>(
                  decoration: InputDecoration(labelText: l10n.selectSale),
                  items: sales
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.id)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedSale = value),
                );
              },
            ),
          ),
          Expanded(
            child: _selectedSale == null
                ? Center(child: Text(l10n.selectASaleToContinue))
                : _buildSaleItems(db),
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

  Widget _buildSaleItems(AppDatabase db) {
    return StreamBuilder<List<SaleItem>>(
      stream: db.salesDao.watchSaleItems(_selectedSale!.id),
      builder: (context, snapshot) {
        final saleItems = snapshot.data ?? [];
        return ListView.builder(
          itemCount: saleItems.length,
          itemBuilder: (context, index) {
            final item = saleItems[index];
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
                      SalesReturnItem(
                        id: const Uuid().v4(),
                        salesReturnId: '', // Will be updated in _processReturn
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
    final newSalesReturn = SalesReturn(
      id: const Uuid().v4(),
      saleId: _selectedSale!.id,
      amountReturned: totalReturnedAmount,
      createdAt: now,
      updatedAt: now,
      syncStatus: 1,
    );

    try {
      await accountingService.postSaleReturn(newSalesReturn, _itemsToReturn);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.returnProcessedSuccessfully)));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
