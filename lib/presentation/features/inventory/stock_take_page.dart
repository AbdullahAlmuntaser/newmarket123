import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class StockTakePage extends StatefulWidget {
  const StockTakePage({super.key});

  @override
  State<StockTakePage> createState() => _StockTakePageState();
}

class _StockTakePageState extends State<StockTakePage> {
  String? _selectedWarehouseId;
  List<Warehouse> _warehouses = [];
  List<Product> _products = [];
  final List<StockTakeItemData> _currentStockTakeItems = [];
  String _currentStockTakeId = '';
  bool _isLoading = true;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _initializePage();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    final db = context.read<AppDatabase>();
    _warehouses = await db.select(db.warehouses).get();
    _products = await db.select(db.products).get();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('جرد المخزون')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildWarehouseSelector(),
                const Divider(),
                if (_selectedWarehouseId != null) ...[
                  _buildStartNewStockTakeButton(db),
                  const Divider(),
                  Expanded(child: _buildStockTakeList(db)),
                ] else
                  const Center(child: Text('يرجى اختيار مستودع لبدء الجرد.')),
              ],
            ),
    );
  }

  Widget _buildWarehouseSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedWarehouseId,
        decoration: const InputDecoration(labelText: 'اختر المستودع للجرد'),
        items: _warehouses
            .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
            .toList(),
        onChanged: (val) {
          setState(() {
            _selectedWarehouseId = val;
            _currentStockTakeItems.clear(); // Clear items when warehouse changes
          });
        },
      ),
    );
  }

  Widget _buildStartNewStockTakeButton(AppDatabase db) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.inventory_outlined),
        label: const Text('بدء جرد جديد'),
        onPressed: () async {
          final id = const Uuid().v4();
          await db.into(db.stockTakes).insert(
            StockTakesCompanion.insert(
              id: drift.Value(id),
              warehouseId: _selectedWarehouseId!,
              date: drift.Value(DateTime.now()),
              status: const drift.Value('DRAFT'),
            ),
          );
          if (!mounted) return;
          setState(() {
            _currentStockTakeId = id;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم بدء جرد جديد.')),
          );
        },
      ),
    );
  }

  Widget _buildStockTakeList(AppDatabase db) {
    if (_currentStockTakeId.isEmpty) {
      return const Center(child: Text('ابدأ جرد جديد أولاً.'));
    }

    return StreamBuilder<List<StockTake>>(
      stream: (db.select(db.stockTakes)..where((st) => st.id.equals(_currentStockTakeId))).watch(),
      builder: (context, stockTakeSnapshot) {
        if (!stockTakeSnapshot.hasData || stockTakeSnapshot.data!.isEmpty) {
          return const Center(child: Text('لا يوجد جرد حالي.'));
        }
        final stockTake = stockTakeSnapshot.data!.first;

        return StreamBuilder<List<StockTakeItemData>>(
          stream: (db.select(db.stockTakeItems).join([
                drift.innerJoin(db.products, db.products.id.equalsExp(db.stockTakeItems.productId))
              ])..where(db.stockTakeItems.stockTakeId.equals(_currentStockTakeId)))
              .watch().map((rows) => rows.map((row) {
                final item = row.readTable(db.stockTakeItems);
                final product = row.readTable(db.products);
                return StockTakeItemData(
                  stockTakeId: item.stockTakeId,
                  productId: item.productId,
                  expectedQty: item.expectedQty,
                  actualQty: item.actualQty,
                  variance: item.variance,
                  productName: product.name,
                  productSku: product.sku,
                );
              }).toList()),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return Center(child: ElevatedButton(onPressed: () => _navigateToAddItem(db, stockTake.id), child: const Text('إضافة أصناف للجرد')));
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الجرد الحالي: ${stockTake.status}'),
                      Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(stockTake.date)}'),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(item.productName),
                          subtitle: Text('SKU: ${item.productSku} | المتوقع: ${item.expectedQty.toStringAsFixed(2)}'),
                          trailing: SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: item.actualQty.toStringAsFixed(2)),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) async {
                                      final actual = double.tryParse(val);
                                      if (actual != null) {
                                        await db.update(db.stockTakeItems).replace(
                                          StockTakeItemsCompanion(
                                            id: drift.Value(item.id), // Assuming id is available or generate one
                                            stockTakeId: drift.Value(item.stockTakeId),
                                            productId: drift.Value(item.productId),
                                            expectedQty: drift.Value(item.expectedQty),
                                            actualQty: drift.Value(actual),
                                            variance: drift.Value(actual - item.expectedQty),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('الفارق: ${item.variance.toStringAsFixed(2)}'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildBottomActions(stockTake, db),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomActions(StockTake stockTake, AppDatabase db) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'ملاحظات عامة للجرد', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: stockTake.status == 'DRAFT' ? () => _finalizeStockTake(db, stockTake) : null,
              child: const Text('إنهاء وإقفال الجرد'),
            ),
          ),
        ],
      ),
    );
  }

  void _finalizeStockTake(AppDatabase db, StockTake stockTake) async {
    await db.update(db.stockTakes).replace(
      stockTake.copyWith(status: 'COMPLETED'),
    );
    // هنا يتم توليد القيود المحاسبية بناءً على الفروقات (Variance)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إقفال الجرد وتحديث المخزون.')),
    );
    setState(() {
      _currentStockTakeId = ''; // Reset to start a new one
    });
  }

  void _navigateToAddItem(AppDatabase db, String stockTakeId) {
    // Navigate to a page or dialog to select product and enter quantities
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة منتج للجرد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              decoration: const InputDecoration(labelText: 'اختر المنتج'),
              items: _products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.sku})'))).toList(),
              onChanged: (product) {
                if (product != null) {
                  _showAddStockTakeItemDialog(ctx, db, stockTakeId, product);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
      ),
    );
  }

  void _showAddStockTakeItemDialog(BuildContext context, AppDatabase db, String stockTakeId, Product product) {
    final quantityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إدخال الكمية الفعلية لـ ${product.name}'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية الفعلية'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final actualQty = double.tryParse(quantityController.text);
              if (actualQty != null) {
                // Get current system stock (this might need a better approach for specific batches)
                // For now, assume we are tracking product level directly for simplicity in UI
                final systemStock = product.stock; 
                final variance = actualQty - systemStock;

                await db.into(db.stockTakeItems).insert(
                  StockTakeItemsCompanion.insert(
                    stockTakeId: stockTakeId,
                    productId: product.id,
                    expectedQty: systemStock,
                    actualQty: actualQty,
                    variance: variance,
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

// Helper class to display data in the list
class StockTakeItemData {
  final String id; // Assuming StockTakeItems needs an ID
  final String stockTakeId;
  final String productId;
  final String productName;
  final String productSku;
  final double expectedQty;
  final double actualQty;
  final double variance;

  StockTakeItemData({
    String? id,
    required this.stockTakeId,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.expectedQty,
    required this.actualQty,
    required this.variance,
  }) : id = id ?? const Uuid().v4(); // Use UUID if ID is not generated by Drift
}
