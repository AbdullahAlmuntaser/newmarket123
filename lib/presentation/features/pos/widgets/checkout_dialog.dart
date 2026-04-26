import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';
import 'package:decimal/decimal.dart';

class CheckoutDialog extends StatefulWidget {
  final PosLoaded state;

  const CheckoutDialog({super.key, required this.state});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  Customer? _selectedCustomer;
  String _paymentMethod = 'cash';
  final TextEditingController _receivedController = TextEditingController();
  Decimal _receivedAmount = Decimal.zero;

  @override
  void initState() {
    super.initState();
    _receivedController.text = widget.state.total.toStringAsFixed(2);
    _receivedAmount = widget.state.total;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.state.total;
    final change = _receivedAmount - total;

    return AlertDialog(
      title: const Text('إتمام عملية البيع'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('المبلغ الإجمالي'),
                  Text(
                    '${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Customer Selection
            CustomerPicker(
              db: context.read<AppDatabase>(),
              value: _selectedCustomer,
              onChanged: (customer) {
                setState(() => _selectedCustomer = customer);
              },
            ),
            const SizedBox(height: 16),
            // Payment Method
            const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('نقداً'), icon: Icon(Icons.money)),
                ButtonSegment(value: 'card', label: Text('بطاقة'), icon: Icon(Icons.credit_card)),
                ButtonSegment(value: 'credit', label: Text('آجل'), icon: Icon(Icons.timer)),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (newSelection) {
                setState(() => _paymentMethod = newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            // Received Amount (only for Cash)
            if (_paymentMethod == 'cash') ...[
              TextField(
                controller: _receivedController,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المستلم',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _receivedAmount = Decimal.tryParse(value) ?? Decimal.zero;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المتبقي (الفكة):'),
                  Text(
                    '${change.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: change >= Decimal.zero ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _canCheckout() ? _onCheckout : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('تأكيد وعرض الفاتورة'),
        ),
      ],
    );
  }

  bool _canCheckout() {
    if (_paymentMethod == 'credit' && _selectedCustomer == null) {
      return false;
    }
    if (_paymentMethod == 'cash' && _receivedAmount < widget.state.total) {
      return false;
    }
    return true;
  }

  void _onCheckout() {
    context.read<PosBloc>().add(CheckoutEvent(
      paymentMethod: _paymentMethod,
      customerId: _selectedCustomer?.id,
    ));
    Navigator.pop(context);
  }
}
