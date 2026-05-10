import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/production_service.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';

class ProductionOrdersPage extends StatefulWidget {
  const ProductionOrdersPage({super.key});

  @override
  State<ProductionOrdersPage> createState() => _ProductionOrdersPageState();
}

class _ProductionOrdersPageState extends State<ProductionOrdersPage> {
  Product? _selectedProduct;
  final _quantityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final productionService = Provider.of<ProductionService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('أوامر الإنتاج')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ProductPicker(
                    db: db,
                    value: _selectedProduct,
                    onChanged: (p) => setState(() => _selectedProduct = p),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (_selectedProduct == null || _quantityController.text.isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await productionService.createProductionOrder(
                        finishedProductId: _selectedProduct!.id,
                        quantity: double.parse(_quantityController.text),
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(const SnackBar(content: Text('تم إنشاء أمر الإنتاج')));
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  },
                  child: const Text('إنشاء أمر'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<ProductionOrder>>(
              stream: (db.select(db.productionOrders)..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final orders = snapshot.data!;
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    return ListTile(
                      title: Text('أمر إنتاج لمنتج: ${o.finishedProductId}'),
                      subtitle: Text('الكمية: ${o.plannedQuantity} - الحالة: ${o.status}'),
                      trailing: o.status == 'PLANNED' 
                        ? ElevatedButton(
                            onPressed: () => productionService.completeProductionOrder(o.id),
                            child: const Text('إكمال'),
                          )
                        : const Icon(Icons.check_circle, color: Colors.green),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
