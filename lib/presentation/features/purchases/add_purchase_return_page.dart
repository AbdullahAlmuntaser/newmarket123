import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';

class AddPurchaseReturnPage extends StatefulWidget {
  const AddPurchaseReturnPage({super.key});

  @override
  State<AddPurchaseReturnPage> createState() => _AddPurchaseReturnPageState();
}

class _AddPurchaseReturnPageState extends State<AddPurchaseReturnPage> {
  Purchase? _selectedPurchase;
  final Map<String, double> _returnedQuantities = {};
  final Map<String, PurchaseItem> _purchaseItemsMap = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newPurchaseReturn)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<Purchase>>(
              stream: db.purchasesDao.watchAllPurchases(),
              builder: (context, snapshot) {
                final purchases = snapshot.data ?? [];
                if (purchases.isEmpty) {
                  return Text(l10n.noPurchasesFound);
                }
                return DropdownButtonFormField<Purchase>(
                  decoration: InputDecoration(
                    labelText: l10n.selectPurchase,
                    border: const OutlineInputBorder(),
                  ),
                  initialValue: _selectedPurchase,
                  items: purchases
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${l10n.purchase} #${p.id.substring(0, 8)} - ${p.total.toStringAsFixed(2)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPurchase = value;
                      _returnedQuantities.clear();
                      _purchaseItemsMap.clear();
                    });
                  },
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: _selectedPurchase == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.selectAPurchaseToContinue,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildPurchaseItems(db),
          ),
        ],
      ),
      bottomNavigationBar: _selectedPurchase != null
          ? _buildSummary(l10n)
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _returnedQuantities.values.any((q) => q > 0)
            ? () => _processReturn()
            : null,
        label: Text(l10n.processReturn),
        icon: const Icon(Icons.check),
      ),
    );
  }

  Widget _buildSummary(AppLocalizations l10n) {
    double totalAmount = 0;
    _returnedQuantities.forEach((productId, qty) {
      final item = _purchaseItemsMap[productId];
      if (item != null) {
        totalAmount += qty * item.price;
      }
    });

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.totalReturnAmount,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            totalAmount.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseItems(AppDatabase db) {
    return StreamBuilder<List<PurchaseItem>>(
      stream: db.purchasesDao.watchPurchaseItems(_selectedPurchase!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final purchaseItems = snapshot.data ?? [];
        for (var item in purchaseItems) {
          _purchaseItemsMap[item.productId] = item;
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: purchaseItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = purchaseItems[index];
            final returnedQty = _returnedQuantities[item.productId] ?? 0.0;

            return FutureBuilder<Product?>(
              future: db.productsDao.getProductById(item.productId),
              builder: (context, productSnapshot) {
                final product = productSnapshot.data;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product?.name ?? item.productId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${AppLocalizations.of(context)!.price}: ${item.price.toStringAsFixed(2)}',
                              ),
                              Text(
                                '${AppLocalizations.of(context)!.quantityLabel}: ${item.quantity}',
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: returnedQty > 0
                                  ? () => setState(
                                      () =>
                                          _returnedQuantities[item.productId] =
                                              returnedQty - 1,
                                    )
                                  : null,
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                returnedQty.toStringAsFixed(0),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: returnedQty < item.quantity
                                  ? () => setState(
                                      () =>
                                          _returnedQuantities[item.productId] =
                                              returnedQty + 1,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _processReturn() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    double totalReturnedAmount = 0;
    final List<PurchaseReturnItemsCompanion> itemCompanions = [];
    final returnId = const Uuid().v4();

    _returnedQuantities.forEach((productId, qty) {
      if (qty > 0) {
        final item = _purchaseItemsMap[productId]!;
        totalReturnedAmount += qty * item.price;
        itemCompanions.add(
          PurchaseReturnItemsCompanion.insert(
            id: Value(const Uuid().v4()),
            purchaseReturnId: returnId,
            productId: productId,
            quantity: qty,
            price: item.price,
            syncStatus: const Value(1),
          ),
        );
      }
    });

    final returnCompanion = PurchaseReturnsCompanion.insert(
      id: Value(returnId),
      purchaseId: _selectedPurchase!.id,
      amountReturned: totalReturnedAmount,
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value(1),
    );

    try {
      await db.purchasesDao.createPurchaseReturn(
        returnCompanion: returnCompanion,
        itemsCompanions: itemCompanions,
        userId: authProvider.currentUser?.id,
      );

      // Post via TransactionEngine
      await sl<TransactionEngine>().postPurchaseReturn(
        returnId,
        userId: authProvider.currentUser?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.returnProcessedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }
}
