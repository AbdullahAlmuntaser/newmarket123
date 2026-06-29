import 'package:flutter/material.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CustomerPaymentResult {
  final Decimal totalAmount;
  final String? note;
  final List<({String saleId, Decimal amount})> allocations;

  CustomerPaymentResult({
    required this.totalAmount,
    this.note,
    required this.allocations,
  });
}

class CustomerPaymentDialog extends StatefulWidget {
  final Customer customer;
  final List<SaleWithBalance> outstandingInvoices;

  const CustomerPaymentDialog({
    super.key,
    required this.customer,
    required this.outstandingInvoices,
  });

  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  final _noteController = TextEditingController();
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, bool> _selected = {};
  final Map<String, Decimal> _balances = {};

  @override
  void initState() {
    super.initState();
    for (final inv in widget.outstandingInvoices) {
      _selected[inv.sale.id] = true;
      _balances[inv.sale.id] = inv.balance;
      _amountControllers[inv.sale.id] = TextEditingController(
        text: inv.balance.toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Decimal get _totalAmount {
    Decimal total = Decimal.zero;
    for (final inv in widget.outstandingInvoices) {
      if (_selected[inv.sale.id] == true) {
        final val =
            Decimal.tryParse(_amountControllers[inv.sale.id]?.text ?? '');
        if (val != null && val > Decimal.zero) {
          total += val;
        }
      }
    }
    return total;
  }

  void _submit() {
    final allocations = <({String saleId, Decimal amount})>[];
    for (final inv in widget.outstandingInvoices) {
      if (_selected[inv.sale.id] == true) {
        final val =
            Decimal.tryParse(_amountControllers[inv.sale.id]?.text ?? '');
        if (val != null && val > Decimal.zero) {
          allocations.add((saleId: inv.sale.id, amount: val));
        }
      }
    }
    if (allocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار فاتورة واحدة على الأقل')),
      );
      return;
    }
    Navigator.pop(
      context,
      CustomerPaymentResult(
        totalAmount: _totalAmount,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        allocations: allocations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('دفع فواتير ${widget.customer.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    ...widget.outstandingInvoices
                        .map((inv) => _buildInvoiceTile(inv)),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'المبلغ الإجمالي: ${_totalAmount.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTile(SaleWithBalance inv) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _selected[inv.sale.id] ?? false,
                  onChanged: (v) {
                    setState(() {
                      _selected[inv.sale.id] = v ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فاتورة #${inv.sale.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'المتبقي: ${inv.balance.toStringAsFixed(2)} ر.س',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_selected[inv.sale.id] == true)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 48),
                child: TextField(
                  controller: _amountControllers[inv.sale.id],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
