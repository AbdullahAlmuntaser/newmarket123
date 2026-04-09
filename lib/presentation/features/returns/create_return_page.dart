import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:uuid/uuid.dart';
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
      transaction = await db.salesDao.getSaleById(id);
      if (transaction != null) {
        items = await (db.select(
          db.saleItems,
        )..where((t) => t.saleId.equals(id))).get();
      }
    } else {
      transaction = await db.purchasesDao.getPurchaseById(id);
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
        : (_selectedTransaction as Purchase).date;

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
                              0.0,
                              (_returnQuantities[item.productId] ?? 0.0) - 1.0,
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    try {
      if (widget.type == ReturnType.sale) {
        await _handleSaleReturn(db, authProvider.currentUser?.id);
      } else {
        await _handlePurchaseReturn(db, authProvider.currentUser?.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.returnProcessedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleSaleReturn(AppDatabase db, String? userId) async {
    final sale = _selectedTransaction as Sale;
    double totalReturnedAmount = 0;
    final List<SalesReturnItemsCompanion> itemCompanions = [];
    final returnId = const Uuid().v4();

    for (var item in _transactionItems) {
      final returnedQty = _returnQuantities[item.productId] ?? 0;
      if (returnedQty > 0) {
        totalReturnedAmount += returnedQty * item.price;
        itemCompanions.add(
          SalesReturnItemsCompanion.insert(
            id: drift.Value(const Uuid().v4()),
            salesReturnId: returnId,
            productId: item.productId,
            quantity: returnedQty,
            price: item.price,
            syncStatus: const drift.Value(1),
          ),
        );
      }
    }

    if (totalReturnedAmount == 0) return;

    final returnCompanion = SalesReturnsCompanion.insert(
      id: drift.Value(returnId),
      saleId: sale.id,
      amountReturned: totalReturnedAmount,
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
      syncStatus: const drift.Value(1),
    );

    await db.salesDao.createSaleReturn(
      returnCompanion: returnCompanion,
      itemsCompanions: itemCompanions,
      userId: userId,
    );
  }

  Future<void> _handlePurchaseReturn(AppDatabase db, String? userId) async {
    final purchase = _selectedTransaction as Purchase;
    double totalReturnedAmount = 0;
    final List<PurchaseReturnItemsCompanion> itemCompanions = [];
    final returnId = const Uuid().v4();

    for (var item in _transactionItems) {
      final returnedQty = _returnQuantities[item.productId] ?? 0;
      if (returnedQty > 0) {
        totalReturnedAmount += returnedQty * item.price;
        itemCompanions.add(
          PurchaseReturnItemsCompanion.insert(
            id: drift.Value(const Uuid().v4()),
            purchaseReturnId: returnId,
            productId: item.productId,
            quantity: returnedQty,
            price: item.price,
            syncStatus: const drift.Value(1),
          ),
        );
      }
    }

    if (totalReturnedAmount == 0) return;

    final returnCompanion = PurchaseReturnsCompanion.insert(
      id: drift.Value(returnId),
      purchaseId: purchase.id,
      amountReturned: totalReturnedAmount,
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
      syncStatus: const drift.Value(1),
    );

    await db.purchasesDao.createPurchaseReturn(
      returnCompanion: returnCompanion,
      itemsCompanions: itemCompanions,
      userId: userId,
    );
  }
}
