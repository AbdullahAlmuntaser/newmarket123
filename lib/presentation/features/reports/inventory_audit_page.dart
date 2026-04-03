import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class InventoryAuditPage extends StatefulWidget {
  const InventoryAuditPage({super.key});

  @override
  State<InventoryAuditPage> createState() => _InventoryAuditPageState();
}

class _InventoryAuditPageState extends State<InventoryAuditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, double> _actualStockValues = {};
  Warehouse? _selectedWarehouse;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryAudit),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.add),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewAuditTab(context, db, l10n),
          _buildAuditHistoryTab(context, db, l10n),
        ],
      ),
    );
  }

  Widget _buildNewAuditTab(
    BuildContext context,
    AppDatabase db,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<Warehouse>>(
            stream: db.select(db.warehouses).watch(),
            builder: (context, snapshot) {
              final warehouses = snapshot.data ?? [];
              if (warehouses.isEmpty) return Text(l10n.noWarehousesFound);

              if (_selectedWarehouse == null && warehouses.isNotEmpty) {
                _selectedWarehouse = warehouses.firstWhere(
                  (w) => w.isDefault,
                  orElse: () => warehouses.first,
                );
              }

              return DropdownButtonFormField<Warehouse>(
                initialValue: _selectedWarehouse,
                decoration: InputDecoration(
                  labelText: l10n.warehouse,
                  border: const OutlineInputBorder(),
                ),
                items: warehouses
                    .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedWarehouse = value;
                  _actualStockValues.clear();
                }),
              );
            },
          ),
        ),
        Expanded(
          child: _selectedWarehouse == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<ProductWithStock>>(
                  stream: _watchProductsWithWarehouseStock(
                    db,
                    _selectedWarehouse!.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final products = snapshot.data ?? [];

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final item = products[index];
                        final product = item.product;
                        final warehouseStock = item.warehouseStock;

                        return Card(
                          child: ListTile(
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${l10n.skuLabel}: ${product.sku} | ${l10n.warehouse}: $warehouseStock',
                            ),
                            trailing: SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: warehouseStock.toString(),
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  final val = double.tryParse(value);
                                  if (val != null) {
                                    _actualStockValues[product.id] = val;
                                  } else {
                                    _actualStockValues.remove(product.id);
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                (_actualStockValues.isEmpty ||
                    _isSaving ||
                    _selectedWarehouse == null)
                ? null
                : () => _saveAudit(context),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle),
            label: Text(l10n.save),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Stream<List<ProductWithStock>> _watchProductsWithWarehouseStock(
    AppDatabase db,
    String warehouseId,
  ) {
    return db.select(db.products).watch().asyncMap((productsList) async {
      List<ProductWithStock> results = [];
      for (var product in productsList) {
        final batches =
            await (db.select(db.productBatches)
                  ..where((b) => b.productId.equals(product.id))
                  ..where((b) => b.warehouseId.equals(warehouseId)))
                .get();

        final warehouseStock = batches.fold(0.0, (sum, b) => sum + b.quantity);
        results.add(
          ProductWithStock(product: product, warehouseStock: warehouseStock),
        );
      }
      return results;
    });
  }

  Widget _buildAuditHistoryTab(
    BuildContext context,
    AppDatabase db,
    AppLocalizations l10n,
  ) {
    return StreamBuilder<List<InventoryAudit>>(
      stream: (db.select(
        db.inventoryAudits,
      )..orderBy([(t) => OrderingTerm.desc(t.auditDate)])).watch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final audits = snapshot.data ?? [];
        if (audits.isEmpty) {
          return const Center(child: Text('No audit history found.'));
        }

        return ListView.builder(
          itemCount: audits.length,
          itemBuilder: (context, index) {
            final audit = audits[index];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                DateFormat('yyyy-MM-dd HH:mm').format(audit.auditDate),
              ),
              subtitle: Text(audit.note ?? 'No notes'),
              onTap: () => _showAuditDetails(context, audit),
            );
          },
        );
      },
    );
  }

  void _showAuditDetails(BuildContext context, InventoryAudit audit) async {
    final db = context.read<AppDatabase>();
    final items = await (db.select(
      db.inventoryAuditItems,
    )..where((t) => t.auditId.equals(audit.id))).get();
    final products = await db.select(db.products).get();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Audit Details - ${DateFormat('yyyy-MM-dd').format(audit.auditDate)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final product = products.firstWhere(
                    (p) => p.id == item.productId,
                    orElse: () => products.first,
                  );
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      'System: ${item.systemStock} | Actual: ${item.actualStock}',
                    ),
                    trailing: Text(
                      '${item.difference > 0 ? "+" : ""}${item.difference}',
                      style: TextStyle(
                        color: item.difference == 0
                            ? Colors.grey
                            : (item.difference > 0 ? Colors.green : Colors.red),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAudit(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    setState(() => _isSaving = true);

    try {
      await db.transaction(() async {
        final auditId = const Uuid().v4();
        await db
            .into(db.inventoryAudits)
            .insert(
              InventoryAuditsCompanion.insert(
                id: Value(auditId),
                auditDate: Value(DateTime.now()),
                note: Value('Audit for Warehouse: ${_selectedWarehouse?.name}'),
              ),
            );

        for (final entry in _actualStockValues.entries) {
          final productId = entry.key;
          final actualStock = entry.value;

          final product = await (db.select(
            db.products,
          )..where((p) => p.id.equals(productId))).getSingle();

          final batches =
              await (db.select(db.productBatches)
                    ..where((b) => b.productId.equals(productId))
                    ..where(
                      (b) => b.warehouseId.equals(_selectedWarehouse!.id),
                    ))
                  .get();

          final systemStock = batches.fold(0.0, (sum, b) => sum + b.quantity);
          final difference = actualStock - systemStock;

          await db
              .into(db.inventoryAuditItems)
              .insert(
                InventoryAuditItemsCompanion.insert(
                  auditId: auditId,
                  productId: productId,
                  systemStock: systemStock,
                  actualStock: actualStock,
                  difference: difference,
                ),
              );

          // Adjust batches
          if (difference < 0) {
            // Loss: Reduce from batches (FIFO-like)
            double remainingToReduce = -difference;
            for (var batch in batches) {
              if (remainingToReduce <= 0) break;
              double reduction = remainingToReduce > batch.quantity
                  ? batch.quantity
                  : remainingToReduce;
              await (db.update(
                db.productBatches,
              )..where((b) => b.id.equals(batch.id))).write(
                ProductBatchesCompanion(
                  quantity: Value(batch.quantity - reduction),
                ),
              );
              remainingToReduce -= reduction;
            }
          } else if (difference > 0) {
            // Gain: Add to a new adjustment batch
            await db
                .into(db.productBatches)
                .insert(
                  ProductBatchesCompanion.insert(
                    id: Value(const Uuid().v4()),
                    productId: productId,
                    warehouseId: _selectedWarehouse!.id,
                    batchNumber: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
                    quantity: Value(difference),
                    initialQuantity: Value(difference),
                    costPrice: Value(product.buyPrice),
                  ),
                );
          }

          // Update product total aggregate stock
          final allBatches = await (db.select(
            db.productBatches,
          )..where((b) => b.productId.equals(productId))).get();
          final totalStock = allBatches.fold(0.0, (sum, b) => sum + b.quantity);
          await (db.update(db.products)..where((p) => p.id.equals(productId)))
              .write(ProductsCompanion(stock: Value(totalStock)));
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.saveSuccess)));
        _actualStockValues.clear();
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

class ProductWithStock {
  final Product product;
  final double warehouseStock;
  ProductWithStock({required this.product, required this.warehouseStock});
}
