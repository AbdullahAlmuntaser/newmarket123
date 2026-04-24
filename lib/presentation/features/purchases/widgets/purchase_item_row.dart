import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/purchases/purchase_provider.dart';
import 'package:provider/provider.dart';

class PurchaseItemRow extends StatefulWidget {
  final int index;
  final PurchaseItemData item;
  final List<Product> products;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const PurchaseItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.products,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<PurchaseItemRow> createState() => _PurchaseItemRowState();
}

class _PurchaseItemRowState extends State<PurchaseItemRow> {
  final _expiryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item.expiryDate != null) {
      _expiryController.text = widget.item.expiryDate!.toString().split(' ')[0];
    }
  }

  @override
  void dispose() {
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${widget.index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildUnitSelector(db),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: widget.item.quantity.toString(),
                    decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.item.quantity = double.tryParse(v) ?? 0.0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: widget.item.unitPrice.toString(),
                    decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.item.unitPrice = double.tryParse(v) ?? 0.0;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: widget.item.batchNumber,
                    decoration: const InputDecoration(labelText: 'رقم الباتش', border: OutlineInputBorder()),
                    onChanged: (v) {
                      widget.item.batchNumber = v;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الانتهاء',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                      );
                      if (date != null) {
                        setState(() {
                          widget.item.expiryDate = date;
                          _expiryController.text = date.toString().split(' ')[0];
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (widget.item.selectedUnit != null && widget.item.selectedUnit!.factor > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'إجمالي الكمية بالوحدة الأساسية: ${(widget.item.quantity * widget.item.selectedUnit!.factor).toStringAsFixed(2)} ${widget.item.product.unit}',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSelector(AppDatabase db) {
    return StreamBuilder<List<UnitConversion>>(
      stream: (db.select(db.unitConversions)..where((t) => t.productId.equals(widget.item.product.id))).watch(),
      builder: (context, snapshot) {
      final conversions = snapshot.data ?? [];
      return DropdownButtonFormField<UnitConversion?>(
        initialValue: widget.item.selectedUnit,
        decoration: const InputDecoration(labelText: 'الوحدة', isDense: true),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(widget.item.product.unit),
          ),
          ...conversions.map((u) => DropdownMenuItem(value: u, child: Text(u.unitName))),
        ],
        onChanged: (value) {
          setState(() {
            widget.item.selectedUnit = value;
            // If a new unit is selected, you might want to adjust the price 
            // based on the factor, for now we just update the unit reference.
          });
          widget.onChanged();
        },
      );
      },

    );
  }
}
