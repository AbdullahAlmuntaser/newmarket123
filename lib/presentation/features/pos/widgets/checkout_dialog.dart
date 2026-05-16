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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _receivedController.text = widget.state.total.toStringAsFixed(2);
    _receivedAmount = widget.state.total;
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.state.total;
    final change = _receivedAmount - total;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 400;

    return AlertDialog(
      title: const Text('إتمام عملية البيع'),
      content: SizedBox(
        width: isWide ? 400 : null,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'المبلغ الإجمالي',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      total.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomerPicker(
                db: context.read<AppDatabase>(),
                value: _selectedCustomer,
                onChanged: (customer) {
                  setState(() => _selectedCustomer = customer);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'طريقة الدفع',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('نقداً'),
                    avatar: const Icon(Icons.money, size: 18),
                    selected: _paymentMethod == 'cash',
                    onSelected: (_) => setState(() => _paymentMethod = 'cash'),
                  ),
                  ChoiceChip(
                    label: const Text('بطاقة'),
                    avatar: const Icon(Icons.credit_card, size: 18),
                    selected: _paymentMethod == 'card',
                    onSelected: (_) => setState(() => _paymentMethod = 'card'),
                  ),
                  ChoiceChip(
                    label: const Text('آجل'),
                    avatar: const Icon(Icons.timer, size: 18),
                    selected: _paymentMethod == 'credit',
                    onSelected: (_) => setState(() => _paymentMethod = 'credit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_paymentMethod == 'cash') ...[
                TextField(
                  controller: _receivedController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستلم',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    setState(() {
                      _receivedAmount = Decimal.tryParse(value) ?? Decimal.zero;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: change >= Decimal.zero
                        ? Colors.green.withAlpha(25)
                        : Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المتبقي (الفكة):'),
                      Text(
                        change.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: change >= Decimal.zero
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _canCheckout() ? _onCheckout : null,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isProcessing ? 'جاري...' : 'تأكيد'),
        ),
      ],
    );
  }

  bool _canCheckout() {
    if (_isProcessing) return false;
    if (_paymentMethod == 'credit' && _selectedCustomer == null) {
      return false;
    }
    if (_paymentMethod == 'cash' && _receivedAmount < widget.state.total) {
      return false;
    }
    return true;
  }

  void _onCheckout() {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    context.read<PosBloc>().add(CheckoutEvent(
          _paymentMethod,
          customerId: _selectedCustomer?.id,
        ));
    Navigator.pop(context);
  }
}
