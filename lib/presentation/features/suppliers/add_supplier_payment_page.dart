import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

class AddSupplierPaymentPage extends StatefulWidget {
  final Supplier supplier;
  const AddSupplierPaymentPage({super.key, required this.supplier});

  @override
  State<AddSupplierPaymentPage> createState() => _AddSupplierPaymentPageState();
}

class _AddSupplierPaymentPageState extends State<AddSupplierPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('سند صرف للمورد: ${widget.supplier.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'الرصيد الحالي المستحق',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        widget.supplier.balance.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال المبلغ';
                  }
                  if (double.tryParse(value) == null) {
                    return 'يرجى إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('تاريخ الدفع'),
                subtitle: Text(_selectedDate.toString().split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePayment,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('حفظ السند'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final paymentId = const Uuid().v4();
    final amount = double.parse(_amountController.text);

    try {
      // 1. Record payment in database
      await db
          .into(db.supplierPayments)
          .insert(
            SupplierPaymentsCompanion.insert(
              id: drift.Value(paymentId),
              supplierId: widget.supplier.id,
              amount: amount,
              paymentDate: drift.Value(_selectedDate),
              syncStatus: const drift.Value(1),
            ),
          );

      // 2. Fire event for accounting
      sl<EventBusService>().fire(
        SupplierPaymentEvent(
          supplierId: widget.supplier.id,
          amount: amount,
          paymentMethod: 'cash',
          paymentId: paymentId,
          note: _noteController.text,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ السند بنجاح')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
