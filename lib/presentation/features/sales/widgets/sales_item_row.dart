import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:provider/provider.dart';

class SalesItemRow extends StatefulWidget {
  final int index;
  final SalesLineItem item;
  final List<Product> products;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final String? customerId;

  const SalesItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.products,
    required this.onDelete,
    required this.onChanged,
    this.customerId,
  });

  @override
  State<SalesItemRow> createState() => _SalesItemRowState();
}

class _SalesItemRowState extends State<SalesItemRow> {
  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.green, child: Text('${widget.index + 1}', style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: Autocomplete<Product>(
                  displayStringForOption: (p) => p.name,
                  initialValue: TextEditingValue(text: widget.item.product?.name ?? ''),
                  optionsBuilder: (v) => widget.products.where((p) => p.name.toLowerCase().contains(v.text.toLowerCase())),
                  onSelected: (p) {
                    setState(() { widget.item.product = p; widget.item.selectedUnit = p.unit; widget.item.price = p.sellPrice; });
                    widget.onChanged();
                  },
                )),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: TextFormField(
                  initialValue: widget.item.quantity.toString(),
                  decoration: const InputDecoration(labelText: 'الكمية'),
                  onChanged: (v) { widget.item.quantity = double.tryParse(v) ?? 0.0; widget.onChanged(); },
                )),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: StreamBuilder<List<CostCenter>>(
                  stream: db.select(db.costCenters).watch(),
                  builder: (context, snapshot) {
                    return DropdownButtonFormField<String?>(
                      value: widget.item.costCenterId,
                      decoration: const InputDecoration(labelText: 'مركز التكلفة'),
                      items: [const DropdownMenuItem(value: null, child: Text('لا يوجد')), ...snapshot.data?.map((cc) => DropdownMenuItem(value: cc.id, child: Text(cc.name))) ?? []],
                      onChanged: (val) { setState(() => widget.item.costCenterId = val); widget.onChanged(); },
                    );
                  },
                )),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: widget.onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SalesLineItem {
  Product? product;
  String selectedUnit;
  double quantity;
  double price;
  double discount;
  double taxRate;
  double unitFactor;
  String? costCenterId;

  double get lineTotal {
    final subtotal = quantity * price;
    final afterDiscount = subtotal - discount;
    return afterDiscount + (afterDiscount * (taxRate / 100));
  }

  SalesLineItem({
    this.product,
    this.selectedUnit = 'حبة',
    this.quantity = 1.0,
    this.price = 0.0,
    this.discount = 0.0,
    this.taxRate = 0.0,
    this.unitFactor = 1.0,
    this.costCenterId,
  });
}
