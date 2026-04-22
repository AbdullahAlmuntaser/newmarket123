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
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('جرد المخزون'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildWarehouseSelector(colorScheme),
                if (_selectedWarehouseId != null) ...[
                  _buildCurrentSessionHeader(db, colorScheme),
                  Expanded(child: _buildStockTakeList(db, colorScheme)),
                ] else
                  Expanded(child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse_outlined, size: 64, color: colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      const Text('يرجى اختيار مستودع لبدء الجرد'),
                    ],
                  ))),
              ],
            ),
      floatingActionButton: _selectedWarehouseId != null && _currentStockTakeId.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToAddItem(db, _currentStockTakeId),
              label: const Text('إضافة صنف'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildWarehouseSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: colorScheme.primaryContainer.withAlpha(50), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedWarehouseId,
        decoration: const InputDecoration(labelText: 'المستودع المستهدف', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white),
        items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
        onChanged: (val) {
          setState(() {
            _selectedWarehouseId = val;
            _currentStockTakeId = '';
          });
        },
      ),
    );
  }

  Widget _buildCurrentSessionHeader(AppDatabase db, ColorScheme colorScheme) {
    if (_currentStockTakeId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: ElevatedButton.icon(
          onPressed: () => _startNewStockTake(db),
          icon: const Icon(Icons.play_arrow),
          label: const Text('بدء جلسة جرد جديدة'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _startNewStockTake(AppDatabase db) async {
    final id = const Uuid().v4();
    await db.into(db.stockTakes).insert(StockTakesCompanion.insert(id: drift.Value(id), warehouseId: _selectedWarehouseId!, date: drift.Value(DateTime.now()), status: const drift.Value('DRAFT')));
    setState(() => _currentStockTakeId = id);
  }

  Widget _buildStockTakeList(AppDatabase db, ColorScheme colorScheme) {
    if (_currentStockTakeId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<StockTake>>(
      stream: (db.select(db.stockTakes)..where((st) => st.id.equals(_currentStockTakeId))).watch(),
      builder: (context, stockTakeSnapshot) {
        if (!stockTakeSnapshot.hasData || stockTakeSnapshot.data!.isEmpty) return const Center(child: Text('جاري التحميل...'));
        final stockTake = stockTakeSnapshot.data!.first;

        return StreamBuilder<List<StockTakeItemData>>(
          stream: (db.select(db.stockTakeItems).join([drift.innerJoin(db.products, db.products.id.equalsExp(db.stockTakeItems.productId))])..where(db.stockTakeItems.stockTakeId.equals(_currentStockTakeId))).watch().map((rows) => rows.map((row) {
                final item = row.readTable(db.stockTakeItems);
                final product = row.readTable(db.products);
                return StockTakeItemData(stockTakeId: item.stockTakeId, productId: item.productId, expectedQty: item.expectedQty, actualQty: item.actualQty, variance: item.variance, productName: product.name, productSku: product.sku);
              }).toList()),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الحالة: ${stockTake.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(DateFormat('yyyy-MM-dd').format(stockTake.date)),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(child: Text('لا توجد أصناف في هذه الجلسة بعد', style: TextStyle(color: colorScheme.outline)))
                      : ListView.builder(
                          itemCount: items.length,
                          padding: const EdgeInsets.only(bottom: 120),
                          itemBuilder: (context, index) => _buildItemCard(items[index], db, colorScheme),
                        ),
                ),
                if (items.isNotEmpty) _buildBottomActions(stockTake, db, colorScheme),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildItemCard(StockTakeItemData item, AppDatabase db, ColorScheme colorScheme) {
    final bool hasVariance = item.variance != 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('SKU: ${item.productSku}', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('المتوقع (النظام)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(item.expectedQty.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: TextEditingController(text: item.actualQty.toStringAsFixed(2)),
                  decoration: const InputDecoration(labelText: 'الكمية الفعلية المكتشفة', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (val) async {
                    final actual = double.tryParse(val);
                    if (actual != null) {
                      await (db.update(db.stockTakeItems)..where((t) => t.stockTakeId.equals(item.stockTakeId) & t.productId.equals(item.productId)))
                          .write(StockTakeItemsCompanion(actualQty: drift.Value(actual), variance: drift.Value(actual - item.expectedQty)));
                    }
                  },
                )),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('الفارق', style: TextStyle(fontSize: 10, color: hasVariance ? Colors.red : Colors.green)),
                  Text(
                    (item.variance > 0 ? '+' : '') + item.variance.toStringAsFixed(2),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: hasVariance ? Colors.red : Colors.green),
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(StockTake stockTake, AppDatabase db, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'ملاحظات نهائية للجرد', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: stockTake.status == 'DRAFT' ? () => _finalizeStockTake(db, stockTake) : null,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
          child: const Text('اعتماد وإقفال الجرد نهائياً', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  void _finalizeStockTake(AppDatabase db, StockTake stockTake) async {
    await (db.update(db.stockTakes)..where((t) => t.id.equals(stockTake.id))).write(const StockTakesCompanion(status: drift.Value('COMPLETED')));
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إقفال الجرد وتحديث المخزون بنجاح'))); setState(() => _currentStockTakeId = ''); }
  }

  void _navigateToAddItem(AppDatabase db, String stockTakeId) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('إضافة منتج للجرد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<Product>(
          decoration: const InputDecoration(labelText: 'اختر المنتج من القائمة', border: OutlineInputBorder()),
          items: _products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.sku})'))).toList(),
          onChanged: (product) { if (product != null) { Navigator.pop(context); _showAddQtyDialog(db, stockTakeId, product); } },
        ),
        const SizedBox(height: 8),
      ]),
    ));
  }

  void _showAddQtyDialog(AppDatabase db, String stockTakeId, Product product) {
    final qtyController = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('كمية ${product.name}'),
      content: TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الفعلية الموجودة الآن'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () async {
          final actual = double.tryParse(qtyController.text);
          if (actual != null) {
            await db.into(db.stockTakeItems).insert(StockTakeItemsCompanion.insert(stockTakeId: stockTakeId, productId: product.id, expectedQty: product.stock, actualQty: actual, variance: actual - product.stock));
            if (ctx.mounted) Navigator.pop(ctx);
          }
        }, child: const Text('إضافة للجرد')),
      ],
    ));
  }
}

class StockTakeItemData {
  final String stockTakeId;
  final String productId;
  final String productName;
  final String productSku;
  final double expectedQty;
  final double actualQty;
  final double variance;
  StockTakeItemData({required this.stockTakeId, required this.productId, required this.productName, required this.productSku, required this.expectedQty, required this.actualQty, required this.variance});
}
