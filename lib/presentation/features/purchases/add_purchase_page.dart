import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  Supplier? _selectedSupplier;
  Warehouse? _selectedWarehouse;
  String _selectedStatus = 'RECEIVED';
  final List<_PurchaseLineItem> _items = [];
  final TextEditingController _invoiceController = TextEditingController();
  bool _isSaving = false;
  bool _isCreditPurchase = true;

  double get _total =>
      _items.fold(0, (sum, item) => sum + (item.quantity * item.price));

  @override
  void initState() {
    super.initState();
    _ensureDefaultWarehouse();
  }

  Future<void> _ensureDefaultWarehouse() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final warehouses = await db.select(db.warehouses).get();
    if (warehouses.isEmpty) {
      final id = const Uuid().v4();
      await db
          .into(db.warehouses)
          .insert(
            WarehousesCompanion.insert(
              id: drift.Value(id),
              name: 'Main Warehouse',
              isDefault: const drift.Value(true),
            ),
          );
      final updated = await db.select(db.warehouses).get();
      setState(() => _selectedWarehouse = updated.first);
    } else {
      setState(
        () => _selectedWarehouse = warehouses.firstWhere(
          (w) => w.isDefault,
          orElse: () => warehouses.first,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newPurchaseInvoice)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(db),
                  const Divider(),
                  _buildItemsList(db),
                ],
              ),
            ),
          ),
          _buildFooter(db),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(db),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<Supplier>>(
                  stream: db.select(db.suppliers).watch(),
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    return DropdownButtonFormField<Supplier>(
                      initialValue: _selectedSupplier,
                      decoration: InputDecoration(
                        labelText: l10n.selectSupplier,
                        border: const OutlineInputBorder(),
                      ),
                      items: suppliers
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedSupplier = value),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: l10n.status,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'DRAFT', child: Text(l10n.draft)),
                    DropdownMenuItem(
                      value: 'ORDERED',
                      child: Text(l10n.ordered),
                    ),
                    DropdownMenuItem(
                      value: 'RECEIVED',
                      child: Text(l10n.received),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedStatus = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _invoiceController,
                  decoration: InputDecoration(
                    labelText: l10n.invoiceNumberLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<List<Warehouse>>(
                  stream: db.select(db.warehouses).watch(),
                  builder: (context, snapshot) {
                    final warehouses = snapshot.data ?? [];
                    return DropdownButtonFormField<Warehouse>(
                      initialValue: _selectedWarehouse,
                      decoration: InputDecoration(
                        labelText: l10n.warehouse,
                        border: const OutlineInputBorder(),
                      ),
                      items: warehouses
                          .map(
                            (w) =>
                                DropdownMenuItem(value: w, child: Text(w.name)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedWarehouse = value),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(child: Text(l10n.noProductsAdded)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(item.product.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.qtyAtPrice(item.quantity, item.price)),
              if (item.batchNumber != null)
                Text('${l10n.batchNumber}: ${item.batchNumber}'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${item.quantity * item.price}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _items.removeAt(index)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.total}:',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_total',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            title: Text(l10n.creditSale),
            value: _isCreditPurchase,
            onChanged: (bool? value) {
              setState(() {
                _isCreditPurchase = value ?? true;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  (_items.isEmpty ||
                      _selectedSupplier == null ||
                      _selectedWarehouse == null ||
                      _isSaving)
                  ? null
                  : () => _savePurchase(db),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(l10n.savePurchase),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(AppDatabase db) async {
    final result = await showDialog<_PurchaseLineItem>(
      context: context,
      builder: (context) => _AddProductToPurchaseDialog(
        db: db,
        isReceived: _selectedStatus == 'RECEIVED',
      ),
    );
    if (result != null) {
      setState(() => _items.add(result));
    }
  }

  Future<void> _savePurchase(AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    final purchaseId = const Uuid().v4();

    try {
      await db.transaction(() async {
        // 1. Create Purchase
        await db
            .into(db.purchases)
            .insert(
              PurchasesCompanion.insert(
                id: drift.Value(purchaseId),
                supplierId: drift.Value(_selectedSupplier!.id),
                total: _total,
                invoiceNumber: drift.Value(_invoiceController.text),
                isCredit: drift.Value(_isCreditPurchase),
                status: drift.Value(_selectedStatus),
                warehouseId: drift.Value(_selectedWarehouse?.id),
                syncStatus: const drift.Value(1),
              ),
            );

        // 2. Create Items and Update Stock if RECEIVED
        for (var item in _items) {
          String? batchId;
          if (_selectedStatus == 'RECEIVED') {
            batchId = const Uuid().v4();
            await db
                .into(db.productBatches)
                .insert(
                  ProductBatchesCompanion.insert(
                    id: drift.Value(batchId),
                    productId: item.product.id,
                    warehouseId: _selectedWarehouse!.id,
                    batchNumber:
                        item.batchNumber ??
                        'AUTO-${DateTime.now().millisecondsSinceEpoch}',
                    expiryDate: drift.Value(item.expiryDate),
                    quantity: drift.Value(item.quantity),
                    initialQuantity: drift.Value(item.quantity),
                    costPrice: drift.Value(item.price),
                  ),
                );

            // Update product aggregate stock and price
            final newStock = item.product.stock + item.quantity;
            await (db.update(
              db.products,
            )..where((t) => t.id.equals(item.product.id))).write(
              ProductsCompanion(
                stock: drift.Value(newStock),
                buyPrice: drift.Value(item.price), // Update last buy price
              ),
            );
          }

          await db
              .into(db.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  productId: item.product.id,
                  quantity: item.quantity,
                  price: item.price,
                  batchId: drift.Value(batchId),
                  syncStatus: const drift.Value(1),
                ),
              );
        }

        // 3. Update Supplier Balance if it's a credit purchase and RECEIVED
        if (_isCreditPurchase && _selectedStatus == 'RECEIVED') {
          final newBalance = _selectedSupplier!.balance + _total;
          await (db.update(db.suppliers)
                ..where((t) => t.id.equals(_selectedSupplier!.id)))
              .write(SuppliersCompanion(balance: drift.Value(newBalance)));
        }

        // 4. Add to Sync Queue
        final payload = {
          'id': purchaseId,
          'supplierId': _selectedSupplier!.id,
          'total': _total,
          'isCredit': _isCreditPurchase,
          'status': _selectedStatus,
          'warehouseId': _selectedWarehouse?.id,
          'items': _items
              .map(
                (i) => {
                  'productId': i.product.id,
                  'qty': i.quantity,
                  'price': i.price,
                  'batchNumber': i.batchNumber,
                  'expiryDate': i.expiryDate?.toIso8601String(),
                },
              )
              .toList(),
        };
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                entityTable: 'purchases',
                entityId: purchaseId,
                operation: 'create',
                payload: jsonEncode(payload),
              ),
            );
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.purchaseSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _PurchaseLineItem {
  final Product product;
  final double quantity;
  final double price;
  final String? batchNumber;
  final DateTime? expiryDate;

  _PurchaseLineItem({
    required this.product,
    required this.quantity,
    required this.price,
    this.batchNumber,
    this.expiryDate,
  });
}

class _AddProductToPurchaseDialog extends StatefulWidget {
  final AppDatabase db;
  final bool isReceived;
  const _AddProductToPurchaseDialog({
    required this.db,
    required this.isReceived,
  });

  @override
  State<_AddProductToPurchaseDialog> createState() =>
      _AddProductToPurchaseDialogState();
}

class _AddProductToPurchaseDialogState
    extends State<_AddProductToPurchaseDialog> {
  Product? _selectedProduct;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  DateTime? _expiryDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addProductToPurchase),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<List<Product>>(
              stream: widget.db.select(widget.db.products).watch(),
              builder: (context, snapshot) {
                final products = snapshot.data ?? [];
                return DropdownButtonFormField<Product>(
                  decoration: InputDecoration(labelText: l10n.productLabel),
                  items: products
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProduct = value;
                      _priceController.text = value?.buyPrice.toString() ?? '';
                    });
                  },
                );
              },
            ),
            TextField(
              controller: _qtyController,
              decoration: InputDecoration(labelText: l10n.quantityLabel),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(labelText: l10n.buyPriceLabel),
              keyboardType: TextInputType.number,
            ),
            if (widget.isReceived) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _batchController,
                decoration: InputDecoration(labelText: l10n.batchNumber),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _expiryDate = date);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l10n.expiryDate),
                  child: Text(
                    _expiryDate == null
                        ? l10n.unknown
                        : _expiryDate!.toString().split(' ')[0],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel.toUpperCase()),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedProduct != null) {
              Navigator.pop(
                context,
                _PurchaseLineItem(
                  product: _selectedProduct!,
                  quantity: double.tryParse(_qtyController.text) ?? 0.0,
                  price: double.tryParse(_priceController.text) ?? 0.0,
                  batchNumber: _batchController.text.isNotEmpty
                      ? _batchController.text
                      : null,
                  expiryDate: _expiryDate,
                ),
              );
            }
          },
          child: Text(l10n.add.toUpperCase()),
        ),
      ],
    );
  }
}
