import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/erp_data_service.dart';
import 'package:supermarket/injection_container.dart';

class PurchaseItemRow extends StatefulWidget {
  final int index;
  final PurchaseLineItem item;
  final List<Product> products;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final String? supplierId;

  const PurchaseItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.products,
    required this.onDelete,
    required this.onChanged,
    this.supplierId,
  });

  @override
  State<PurchaseItemRow> createState() => _PurchaseItemRowState();
}

class _PurchaseItemRowState extends State<PurchaseItemRow> {
  ProductSmartData? _smartData;
  SupplierSmartData? _supplierSmartData;
  bool _isLoadingSmartData = false;

  Future<void> _fetchSmartData(String productId) async {
    setState(() => _isLoadingSmartData = true);
    try {
      final erpService = sl<ErpDataService>();
      final data = await erpService.getProductSmartData(productId);
      
      SupplierSmartData? supplierData;
      if (widget.supplierId != null) {
        supplierData = await erpService.getSupplierSmartData(widget.supplierId!, productId: productId);
      }

      setState(() {
        _smartData = data;
        _supplierSmartData = supplierData;
        _isLoadingSmartData = false;
      });
    } catch (e) {
      setState(() => _isLoadingSmartData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                  child: Autocomplete<Product>(
                    displayStringForOption: (p) => p.name,
                    initialValue: TextEditingValue(text: widget.item.product?.name ?? ''),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return widget.products;
                      }
                      return widget.products.where((p) {
                        return p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                            (p.sku.toLowerCase().contains(textEditingValue.text.toLowerCase())) ||
                            (p.barcode?.contains(textEditingValue.text) ?? false);
                      });
                    },
                    onSelected: (Product selection) {
                      setState(() {
                        widget.item.product = selection;
                        widget.item.selectedUnit = selection.unit;
                        widget.item.price = selection.buyPrice;
                      });
                      _fetchSmartData(selection.id);
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: widget.item.quantity.toString(),
                    decoration: const InputDecoration(labelText: 'الكمية'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      widget.item.quantity = double.tryParse(value) ?? 0.0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: widget.item.price.toString(),
                    decoration: const InputDecoration(labelText: 'السعر'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      widget.item.price = double.tryParse(value) ?? 0.0;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            if (widget.item.product != null) ...[
              const SizedBox(height: 8),
              _buildSmartInfoArea(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInfoArea() {
    if (_isLoadingSmartData) {
      return const LinearProgressIndicator();
    }

    if (_smartData == null) return const SizedBox.shrink();

    final isPriceHigh = widget.item.price > _smartData!.averageCost && _smartData!.averageCost > 0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoTile('المخزون', '${_smartData!.currentStock}'),
              _infoTile('متوسط التكلفة', _smartData!.averageCost.toStringAsFixed(2)),
              _infoTile('آخر سعر', _smartData!.lastPurchasePrice.toStringAsFixed(2)),
              if (_supplierSmartData != null)
                _infoTile('آخر سعر (المورد)', _supplierSmartData!.lastPurchasePriceForProduct.toStringAsFixed(2)),
            ],
          ),
          if (isPriceHigh)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'السعر الحالي أعلى من متوسط التكلفة (${_smartData!.averageCost.toStringAsFixed(2)})',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class PurchaseLineItem {
  Product? product;
  String selectedUnit;
  double quantity;
  double price;
  double discount;
  double taxRate;

  double get lineTotal {
    final subtotal = quantity * price;
    final afterDiscount = subtotal - discount;
    return afterDiscount + (afterDiscount * (taxRate / 100));
  }

  PurchaseLineItem({
    this.product,
    this.selectedUnit = 'حبة',
    this.quantity = 0.0,
    this.price = 0.0,
    this.discount = 0.0,
    this.taxRate = 0.0,
  });
}
