import 'package:flutter/material.dart' hide Column;
import 'package:flutter/material.dart' show Column;
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:drift/drift.dart' hide JsonKey, Column;
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';

class AddSalesReturnPage extends StatefulWidget {
  final String? saleId;
  const AddSalesReturnPage({super.key, this.saleId});

  @override
  State<AddSalesReturnPage> createState() => _AddSalesReturnPageState();
}

class _AddSalesReturnPageState extends State<AddSalesReturnPage> {
  Sale? _selectedSale;
  final Map<String, double> _returnedQuantities = {};
  final Map<String, SaleItem> _saleItemsMap = {};

  @override
  void initState() {
    super.initState();
    if (widget.saleId != null) {
      _loadSelectedSale(widget.saleId!);
    }
  }

  Future<void> _loadSelectedSale(String saleId) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final sale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingleOrNull();
    if (sale != null) {
      setState(() {
        _selectedSale = sale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newSalesReturn)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<Sale>>(
              stream: db.salesDao.watchAllSales(),
              builder: (context, snapshot) {
                final salesList = snapshot.data ?? [];
                if (salesList.isEmpty) {
                  return Text(l10n.noSalesFound);
                }
                return DropdownButtonFormField<Sale>(
                  decoration: InputDecoration(
                    labelText: l10n.selectSale,
                    border: const OutlineInputBorder(),
                  ),
                  initialValue: _selectedSale,
                  items: salesList
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${l10n.sale} #${s.id.substring(0, 8)} - ${s.total.toStringAsFixed(2)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSale = value;
                      _returnedQuantities.clear();
                      _saleItemsMap.clear();
                    });
                  },
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: _selectedSale == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.selectASaleToContinue,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildSaleItems(db),
          ),
        ],
      ),
      bottomNavigationBar: _selectedSale != null ? _buildSummary(l10n) : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _returnedQuantities.values.any((q) => q > 0)
            ? _processReturn
            : null,
        label: Text(l10n.processReturn),
        icon: const Icon(Icons.check),
        backgroundColor: _returnedQuantities.values.any((q) => q > 0)
            ? null
            : Colors.grey,
      ),
    );
  }

  Widget _buildSummary(AppLocalizations l10n) {
    double totalAmount = 0;
    _returnedQuantities.forEach((productId, qty) {
      final item = _saleItemsMap[productId];
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
            color: Colors.black.withAlpha(12), // Replaced withOpacity
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

  Widget _buildSaleItems(AppDatabase db) {
    return StreamBuilder<List<SaleItem>>(
      stream: db.salesDao.watchSaleItems(_selectedSale!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final saleItems = snapshot.data ?? [];
        for (var item in saleItems) {
          _saleItemsMap[item.productId] = item;
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: saleItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = saleItems[index];
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
    final l10n = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_selectedSale == null) return;

    double totalReturnedAmount = 0;
    final List<SalesReturnItemsCompanion> itemCompanions = [];
    final returnId = const Uuid().v4();

    _returnedQuantities.forEach((productId, qty) {
      if (qty > 0) {
        final item = _saleItemsMap[productId]!;
        totalReturnedAmount += qty * item.price;
        itemCompanions.add(
          SalesReturnItemsCompanion.insert(
            id: Value(const Uuid().v4()),
            salesReturnId: returnId,
            productId: productId,
            quantity: qty,
            price: item.price,
            syncStatus: const Value(1),
          ),
        );
      }
    });

    final returnCompanion = SalesReturnsCompanion.insert(
      id: Value(returnId),
      saleId: _selectedSale!.id,
      amountReturned: totalReturnedAmount,
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value(1),
    );

    try {
      await db.salesDao.createSaleReturn(
        returnCompanion: returnCompanion,
        itemsCompanions: itemCompanions,
        userId: authProvider.currentUser?.id,
      );

      // Post via TransactionEngine
      await sl<TransactionEngine>().postSaleReturn(
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
