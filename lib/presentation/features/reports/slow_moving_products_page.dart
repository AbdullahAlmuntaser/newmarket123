import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/core/utils/export_service.dart';

class SlowMovingProductsPage extends StatefulWidget {
  const SlowMovingProductsPage({super.key});

  @override
  State<SlowMovingProductsPage> createState() => _SlowMovingProductsPageState();
}

class _SlowMovingProductsPageState extends State<SlowMovingProductsPage> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  int _daysThreshold = 90;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = di.sl<AppDatabase>();

    final products = await db.select(db.products).get();
    final sales = await db.select(db.sales).get();
    final saleItems = await db.select(db.saleItems).get();

    final cutoffDate = DateTime.now().subtract(Duration(days: _daysThreshold));
    final recentSales =
        sales.where((s) => s.createdAt.isAfter(cutoffDate)).toList();
    final recentSaleIds = recentSales.map((s) => s.id).toSet();

    final productSalesCount = <String, int>{};
    for (final item in saleItems) {
      if (recentSaleIds.contains(item.saleId)) {
        productSalesCount[item.productId] =
            (productSalesCount[item.productId] ?? 0) + 1;
      }
    }

    _products = products
        .where((p) {
          final salesCount = productSalesCount[p.id] ?? 0;
          return salesCount <= 2 && p.stock > Decimal.zero;
        })
        .map((p) => {
              'product': p,
              'salesCount': productSalesCount[p.id] ?? 0,
            })
        .toList();

    _products.sort(
        (a, b) => (a['salesCount'] as int).compareTo(b['salesCount'] as int));

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات الراكدة'),
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf), onPressed: _export),
          IconButton(icon: const Icon(Icons.table_chart), onPressed: _export),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Text('منذ '),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: _daysThreshold.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                    onChanged: (val) {
                      final days = int.tryParse(val) ?? 90;
                      setState(() {
                        _daysThreshold = days;
                        _loadData();
                      });
                    },
                  ),
                ),
                const Text(' يوم'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('لا توجد منتجات راكدة'))
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final item = _products[index];
                          final product = item['product'] as Product;
                          final salesCount = item['salesCount'] as int;
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                                'SKU: ${product.sku} | المخزون: ${product.stock}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('مبيعات: $salesCount',
                                    style: const TextStyle(fontSize: 12)),
                                Text(
                                    'القيمة: ${(product.stock * product.sellPrice).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.orange)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _export() async {
    final service = ExportService(di.sl<AppDatabase>());
    await service.exportToCsv(
        'slow_moving_products',
        _products.map((item) {
          final p = item['product'] as Product;
          return {
            'name': p.name,
            'sku': p.sku,
            'stock': p.stock.toString(),
            'salesCount': item['salesCount'].toString()
          };
        }).toList());
  }
}
