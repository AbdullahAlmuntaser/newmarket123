import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';

/// صفحة سند القبض/الصرف اليدوي
class ManualVoucherPage extends StatefulWidget {
  final bool isReceipt; // true = سند قبض, false = سند صرف
  const ManualVoucherPage({super.key, this.isReceipt = true});

  @override
  State<ManualVoucherPage> createState() => _ManualVoucherPageState();
}

class _ManualVoucherPageState extends State<ManualVoucherPage> {
  Customer? _selectedCustomer;
  Supplier? _selectedSupplier;
  String _paymentMethod = 'cash';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.isReceipt ? 'سند قبض' : 'سند صرف')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // نوع الطرف
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isReceipt ? 'القبض من' : 'الصرف إلى',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'customer', label: Text('عميل')),
                        ButtonSegment(value: 'supplier', label: Text('مورد')),
                      ],
                      selected: {
                        _selectedCustomer != null ? 'customer' : 'supplier',
                      },
                      onSelectionChanged: (selection) {
                        setState(() {
                          if (selection.contains('customer')) {
                            _selectedSupplier = null;
                          } else {
                            _selectedCustomer = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // اختيار العميل
            if (_selectedCustomer == null || _selectedSupplier == null)
              _selectedCustomer == null
                  ? _buildCustomerSelector(db)
                  : _buildSupplierSelector(db),

            const SizedBox(height: 16),

            // المبلغ
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المبلغ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // طريقة الدفع
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طريقة الدفع',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                        DropdownMenuItem(value: 'bank', child: Text('بنكي')),
                        DropdownMenuItem(value: 'check', child: Text('شيك')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // التاريخ
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'التاريخ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _dateController.text = _formatDate(date);
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(_formatDate(_selectedDate)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ملاحظات
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملاحظات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'ملاحظات إضافية...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // زر الحفظ
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveVoucher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isReceipt
                                ? Icons.receipt_long
                                : Icons.money_off,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isReceipt
                                ? 'حفظ سند القبض'
                                : 'حفظ سند الصرف',
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSelector(AppDatabase db) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Customer>>(
          stream: db.select(db.customers).watch(),
          builder: (context, snapshot) {
            final customers = snapshot.data ?? [];
            return DropdownButtonFormField<Customer>(
              initialValue: _selectedCustomer,
              decoration: const InputDecoration(
                labelText: 'اختر العميل',
                border: OutlineInputBorder(),
              ),
              items: customers
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCustomer = value;
                  _selectedSupplier = null;
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSupplierSelector(AppDatabase db) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Supplier>>(
          stream: db.select(db.suppliers).watch(),
          builder: (context, snapshot) {
            final suppliers = snapshot.data ?? [];
            return DropdownButtonFormField<Supplier>(
              initialValue: _selectedSupplier,
              decoration: const InputDecoration(
                labelText: 'اختر المورد',
                border: OutlineInputBorder(),
              ),
              items: suppliers
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSupplier = value;
                  _selectedCustomer = null;
                });
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveVoucher() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')));
      return;
    }

    if (_selectedCustomer == null && _selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار عميل أو مورد')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final engine = sl<TransactionEngine>();

      if (_selectedCustomer != null) {
        await engine.postCustomerPayment(
          customerId: _selectedCustomer!.id,
          amount: amount,
          paymentMethod: _paymentMethod,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
      } else if (_selectedSupplier != null) {
        await engine.postSupplierPayment(
          supplierId: _selectedSupplier!.id,
          amount: amount,
          paymentMethod: _paymentMethod,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isReceipt
                  ? 'تم حفظ سند القبض بنجاح'
                  : 'تم حفظ سند الصرف بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
