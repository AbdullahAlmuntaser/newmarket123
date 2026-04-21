import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/erp_data_service.dart';
import 'package:supermarket/injection_container.dart';

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
  ProductSmartData? _smartData;
  CustomerSmartData? _customerSmartData;
  bool _isLoadingSmartData = false;

  Future<void> _fetchSmartData(String productId) async {
    setState(() => _isLoadingSmartData = true);
    try {
      final erpService = sl<ErpDataService>();
      final data = await erpService.getProductSmartData(productId);
      
      CustomerSmartData? customerData;
      if (widget.customerId != null) {
        customerData = await erpService.getCustomerSmartData(widget.customerId!, productId: productId);
      }

      setState(() {
        _smartData = data;
        _customerSmartData = customerData;
        _isLoadingSmartData = false;
        
        // Auto-set price if not set
        if (widget.item.price == 0) {
           widget.item.price = data.retailPrice;
        }
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
                CircleAvatar(backgroundColor: Colors.green, child: Text('${widget.index + 1}', style: const TextStyle(color: Colors.white))),
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
                        widget.item.price = selection.sellPrice;
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
                    key: ValueKey(widget.item.price),
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

    final isPriceLow = widget.item.price < _smartData!.averageCost && _smartData!.averageCost > 0;
    final isStockLow = _smartData!.currentStock < widget.item.quantity;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoTile('المتوفر', '${_smartData!.currentStock}', color: isStockLow ? Colors.red : null),
              _infoTile('سعر التجزئة', _smartData!.retailPrice.toStringAsFixed(2), onTap: () {
                setState(() => widget.item.price = _smartData!.retailPrice);
                widget.onChanged();
              }),
              _infoTile('سعر الجملة', _smartData!.wholesalePrice.toStringAsFixed(2), onTap: () {
                setState(() => widget.item.price = _smartData!.wholesalePrice);
                widget.onChanged();
              }),
              if (_customerSmartData != null)
                _infoTile('آخر سعر (العميل)', _customerSmartData!.lastSalePriceForProduct.toStringAsFixed(2), onTap: () {
                  setState(() => widget.item.price = _customerSmartData!.lastSalePriceForProduct);
                  widget.onChanged();
                }),
            ],
          ),
          if (isPriceLow)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'السعر أقل من التكلفة (${_smartData!.averageCost.toStringAsFixed(2)})',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (isStockLow)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'الكمية المطلوبة أكبر من المخزون المتاح',
                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
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
  });
}
