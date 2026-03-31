import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dart:math';

enum ReturnType { sale, purchase }

class CreateReturnPage extends StatefulWidget {
  final ReturnType type;

  const CreateReturnPage({super.key, required this.type});

  @override
  State<CreateReturnPage> createState() => _CreateReturnPageState();
}

class _CreateReturnPageState extends State<CreateReturnPage> {
  final _searchController = TextEditingController();
  dynamic _selectedTransaction;
  List<dynamic> _transactionItems = [];
  final Map<String, double> _returnQuantities = {};
  bool _isLoading = false;
  bool _notFound = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.type == ReturnType.sale
        ? l10n.fromSale
        : l10n.fromPurchase;

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.createReturn} - $title')),
      body: Column(
        children: [
          _buildSearch(context, l10n),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_notFound)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(l10n.invoiceNotFound),
              ),
            ),
          if (!_isLoading && _selectedTransaction != null)
            Expanded(child: _buildTransactionDetails(l10n)),
        ],
      ),
      floatingActionButton: _returnQuantities.values.any((q) => q > 0)
          ? FloatingActionButton.extended(
              onPressed: _processReturn,
              label: Text(l10n.save),
              icon: const Icon(Icons.check),
            )
          : null,
    );
  }

  Widget _buildSearch(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: l10n.searchByInvoiceId,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchTransaction,
          ),
        ),
        onSubmitted: (_) => _searchTransaction(),
      ),
    );
  }

  Future<void> _searchTransaction() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final id = _searchController.text;
    if (id.isEmpty) return;

    setState(() {
      _isLoading = true;
      _notFound = false;
      _selectedTransaction = null;
      _transactionItems = [];
      _returnQuantities.clear();
    });

    dynamic transaction;
    List<dynamic> items = [];

    if (widget.type == ReturnType.sale) {
      transaction = await (db.select(
        db.sales,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (transaction != null) {
        items = await (db.select(
          db.saleItems,
        )..where((t) => t.saleId.equals(id))).get();
      }
    } else {
      transaction = await (db.select(
        db.purchases,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (transaction != null) {
        items = await (db.select(
          db.purchaseItems,
        )..where((t) => t.purchaseId.equals(id))).get();
      }
    }

    setState(() {
      _selectedTransaction = transaction;
      _transactionItems = items;
      if (transaction == null) {
        _notFound = true;
      }
      for (var item in items) {
        _returnQuantities[item.productId] = 0;
      }
      _isLoading = false;
    });
  }

  Widget _buildTransactionDetails(AppLocalizations l10n) {
    final txDate = widget.type == ReturnType.sale
        ? (_selectedTransaction as Sale).createdAt
        : (_selectedTransaction as Purchase).createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.invoiceLabel(_selectedTransaction.id.substring(0, 8)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(l10n.dateLabel(DateFormat.yMMMd().format(txDate))),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _transactionItems.length,
            itemBuilder: (context, index) {
              final item = _transactionItems[index];
              final originalQty = item.quantity;

              return Card(
                child: ListTile(
                  title: FutureBuilder<Product?>(
                    future: Provider.of<AppDatabase>(
                      context,
                      listen: false,
                    ).productsDao.getProductById(item.productId),
                    builder: (context, snapshot) =>
                        Text(snapshot.data?.name ?? 'Loading...'),
                  ),
                  subtitle: Text(
                    '${l10n.quantityLabel}: $originalQty @ ${item.price}',
                  ),
                  trailing: SizedBox(
                    width: 150,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(
                            () => _returnQuantities[item.productId] = max(
                              0,
                              (_returnQuantities[item.productId] ?? 0) - 1,
                            ),
                          ),
                          icon: const Icon(Icons.remove),
                        ),
                        Text(
                          (_returnQuantities[item.productId] ?? 0)
                              .toStringAsFixed(0),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _returnQuantities[item.productId] = min(
                              originalQty,
                              (_returnQuantities[item.productId] ?? 0) + 1,
                            ),
                          ),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _processReturn() async {
    final db = Provider.of<AppDatabase>(context, listen: false);

    await db.transaction(() async {
      if (widget.type == ReturnType.sale) {
        await _handleSaleReturn(db);
      } else {
        await _handlePurchaseReturn(db);
      }
    });

    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleSaleReturn(AppDatabase db) async {
    final sale = _selectedTransaction as Sale;
    double totalReturnedAmount = 0;

    for (var item in _transactionItems) {
      final returnedQty = _returnQuantities[item.productId] ?? 0;
      if (returnedQty > 0) {
        totalReturnedAmount += returnedQty * item.price;
      }
    }
    if (totalReturnedAmount == 0) return;

    final returnCompanion = SalesReturnsCompanion.insert(
      saleId: sale.id,
      amountReturned: totalReturnedAmount,
      syncStatus: const drift.Value(1),
    );
    final newReturn = await db
        .into(db.salesReturns)
        .insertReturning(returnCompanion);

    for (var item in _transactionItems) {
      final returnedQty = _returnQuantities[item.productId] ?? 0;
      if (returnedQty > 0) {
        await db
            .into(db.salesReturnItems)
            .insert(
              SalesReturnItemsCompanion.insert(
                salesReturnId: newReturn.id,
                productId: item.productId,
                quantity: returnedQty,
                price: item.price,
                syncStatus: const drift.Value(1),
              ),
            );

        final product = await (db.select(
          db.products,
        )..where((p) => p.id.equals(item.productId))).getSingle();
        await (db.update(
          db.products,
        )..where((p) => p.id.equals(item.productId))).write(
          ProductsCompanion(stock: drift.Value(product.stock + returnedQty)),
        );
      }
    }

    if (sale.isCredit && sale.customerId != null) {
      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals(sale.customerId!))).getSingle();
      await (db.update(
        db.customers,
      )..where((c) => c.id.equals(sale.customerId!))).write(
        CustomersCompanion(
          balance: drift.Value(customer.balance - totalReturnedAmount),
        ),
      );
    }
  }

  Future<void> _handlePurchaseReturn(AppDatabase db) async {
    final purchase = _selectedTransaction as Purchase;
    double totalReturnedAmount = 0;

    for (var item in _transactionItems) {
      final returnedQty = _returnQuantities[item.productId] ?? 0;
      if (returnedQty > 0) {
        totalReturnedAmount += returnedQty * item.price;
      }
    }
    if (totalReturnedAmount == 0) return;

    final returnCompanion = PurchaseReturnsCompanion.insert(
      purchaseId: purchase.id,
      amountReturned: totalReturnedAmount,
      syncStatus: const drift.Value(1),
    );
    final newReturn = await db
        .into(db.purchaseReturns)
        .insertReturning(returnCompanion);

    for (var item in _transactionItems) {
      final returnedQty = _returnQuantities[item.productId] ?? 0;
      if (returnedQty > 0) {
        await db
            .into(db.purchaseReturnItems)
            .insert(
              PurchaseReturnItemsCompanion.insert(
                purchaseReturnId: newReturn.id,
                productId: item.productId,
                quantity: returnedQty,
                price: item.price,
                syncStatus: const drift.Value(1),
              ),
            );

        final product = await (db.select(
          db.products,
        )..where((p) => p.id.equals(item.productId))).getSingle();
        await (db.update(
          db.products,
        )..where((p) => p.id.equals(item.productId))).write(
          ProductsCompanion(stock: drift.Value(product.stock - returnedQty)),
        );
      }
    }

    if (purchase.supplierId != null) {
      final supplier = await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(purchase.supplierId!))).getSingle();
      await (db.update(
        db.suppliers,
      )..where((s) => s.id.equals(purchase.supplierId!))).write(
        SuppliersCompanion(
          balance: drift.Value(supplier.balance - totalReturnedAmount),
        ),
      );
    }
  }
}
