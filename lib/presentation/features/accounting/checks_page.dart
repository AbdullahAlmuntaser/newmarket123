import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/core/services/accounting_service.dart';

class ChecksPage extends StatefulWidget {
  const ChecksPage({super.key});

  @override
  State<ChecksPage> createState() => _ChecksPageState();
}

class _ChecksPageState extends State<ChecksPage> {
  final _formKey = GlobalKey<FormState>();
  final _checkNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDueDate;
  String _selectedType = 'RECEIVED'; // RECEIVED, ISSUED
  String? _selectedPartnerId;
  String? _selectedAccountId;
  String _selectedStatus = 'PENDING';

  @override
  void dispose() {
    _checkNumberController.dispose();
    _bankNameController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _presentDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDueDate = pickedDate;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  void _clearForm() {
    _checkNumberController.clear();
    _bankNameController.clear();
    _amountController.clear();
    _dueDateController.clear();
    _noteController.clear();
    setState(() {
      _selectedDueDate = null;
      _selectedPartnerId = null;
      _selectedAccountId = null;
      _selectedStatus = 'PENDING';
    });
  }

  Future<void> _saveCheck() async {
    if (!_formKey.currentState!.validate()) return;

    final db = context.read<AppDatabase>();
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final check = ChecksCompanion.insert(
      id: drift.Value(const Uuid().v4()),
      checkNumber: _checkNumberController.text,
      bankName: _bankNameController.text,
      dueDate: _selectedDueDate!,
      amount: amount,
      type: _selectedType,
      status: drift.Value(_selectedStatus),
      partnerId: drift.Value(_selectedPartnerId),
      note: drift.Value(_noteController.text),
      paymentAccountId: drift.Value(_selectedAccountId),
    );

    await db.into(db.checks).insert(check);
    _clearForm();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الشيك بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الشيكات')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: 'نوع الشيك', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'RECEIVED', child: Text('شيكات مستلمة (من العملاء)')),
                        DropdownMenuItem(value: 'ISSUED', child: Text('شيكات صادرة (للموردين)')),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedType = val!;
                        _selectedPartnerId = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _buildPartnerSelector(db),
                    const SizedBox(height: 16),
                    _buildAccountSelector(db),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _checkNumberController,
                      decoration: const InputDecoration(labelText: 'رقم الشيك', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(labelText: 'اسم البنك', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => double.tryParse(v ?? '') == null ? 'مبلغ غير صحيح' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dueDateController,
                      decoration: const InputDecoration(labelText: 'تاريخ الاستحقاق', border: OutlineInputBorder()),
                      readOnly: true,
                      onTap: _presentDatePicker,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveCheck,
                      child: const Text('حفظ الشيك'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            SizedBox(
              height: 400,
              child: _buildChecksList(db),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerSelector(AppDatabase db) {
    if (_selectedType == 'RECEIVED') {
      return StreamBuilder<List<Customer>>(
        stream: db.select(db.customers).watch(),
        builder: (context, snapshot) {
          final customers = snapshot.data ?? [];
          return DropdownButtonFormField<String>(
            initialValue: _selectedPartnerId,
            decoration: const InputDecoration(labelText: 'العميل', border: OutlineInputBorder()),
            items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (val) => setState(() => _selectedPartnerId = val),
            validator: (v) => v == null ? 'مطلوب' : null,
          );
        },
      );
    } else {
      return StreamBuilder<List<Supplier>>(
        stream: db.select(db.suppliers).watch(),
        builder: (context, snapshot) {
          final suppliers = snapshot.data ?? [];
          return DropdownButtonFormField<String>(
            initialValue: _selectedPartnerId,
            decoration: const InputDecoration(labelText: 'المورد', border: OutlineInputBorder()),
            items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (val) => setState(() => _selectedPartnerId = val),
            validator: (v) => v == null ? 'مطلوب' : null,
          );
        },
      );
    }
  }

  Widget _buildAccountSelector(AppDatabase db) {
    return StreamBuilder<List<GLAccount>>(
      stream: (db.select(db.gLAccounts)..where((a) => a.code.equals(AccountingService.codeCash) | a.code.equals(AccountingService.codeBank))).watch(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];
        return DropdownButtonFormField<String>(
          initialValue: _selectedAccountId,
          decoration: const InputDecoration(labelText: 'حساب الدفع/التحصيل', border: OutlineInputBorder()),
          items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
          onChanged: (val) => setState(() => _selectedAccountId = val),
          validator: (v) => v == null ? 'مطلوب' : null,
        );
      },
    );
  }

  Widget _buildChecksList(AppDatabase db) {
    final checksStream = (db.select(db.checks)..where((c) => c.type.equals(_selectedType))).watch();

    return StreamBuilder<List<Check>>(
      stream: checksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final checks = snapshot.data ?? [];
        if (checks.isEmpty) return const Center(child: Text('لا يوجد شيكات.'));

        return ListView.builder(
          itemCount: checks.length,
          itemBuilder: (context, index) {
            final check = checks[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('رقم الشيك: ${check.checkNumber} - ${check.bankName}'),
                subtitle: Text('المبلغ: ${check.amount} - الاستحقاق: ${DateFormat('yyyy-MM-dd').format(check.dueDate)}\nالحالة: ${check.status}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) => _updateCheckStatus(db, check, val),
                  itemBuilder: (context) => [
                    if (check.status == 'PENDING') const PopupMenuItem(value: 'COLLECTED', child: Text('تحصيل')),
                    if (check.status == 'PENDING') const PopupMenuItem(value: 'BOUNCED', child: Text('رفض')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateCheckStatus(AppDatabase db, Check check, String newStatus) async {
    final accountingService = context.read<AccountingService>();
    
    await (db.update(db.checks)..where((c) => c.id.equals(check.id))).write(
      ChecksCompanion(status: drift.Value(newStatus)),
    );

    final updatedCheck = check.copyWith(status: newStatus);

    if (newStatus == 'COLLECTED') {
      await accountingService.recordCheckCollected(updatedCheck);
    } else if (newStatus == 'BOUNCED') {
      await accountingService.recordCheckBounced(updatedCheck);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديث حالة الشيك إلى $newStatus')));
    }
  }
}
