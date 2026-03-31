import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AddEditCustomerDialog extends StatefulWidget {
  final Customer? customer;

  const AddEditCustomerDialog({super.key, this.customer});

  @override
  State<AddEditCustomerDialog> createState() => _AddEditCustomerDialogState();
}

class _AddEditCustomerDialogState extends State<AddEditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _creditLimitController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.customer?.phone ?? '',
    );
    _creditLimitController = TextEditingController(
      text: widget.customer?.creditLimit.toString() ?? '0.0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.customer == null ? l10n.addCustomer : l10n.editCustomer,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.customerName),
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterNameError : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: l10n.phoneLabel),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _creditLimitController,
                decoration: InputDecoration(labelText: l10n.creditLimitLabel),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel.toUpperCase()),
        ),
        ElevatedButton(
          onPressed: _saveCustomer,
          child: Text(l10n.save.toUpperCase()),
        ),
      ],
    );
  }

  void _saveCustomer() {
    if (_formKey.currentState!.validate()) {
      final companion = CustomersCompanion(
        name: drift.Value(_nameController.text),
        phone: drift.Value(_phoneController.text),
        creditLimit: drift.Value(
          double.tryParse(_creditLimitController.text) ?? 0.0,
        ),
        syncStatus: const drift.Value(1), // Pending sync
      );
      Navigator.pop(context, companion);
    }
  }
}
