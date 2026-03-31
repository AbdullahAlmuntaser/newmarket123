import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AddEditSupplierDialog extends StatefulWidget {
  final Supplier? supplier;

  const AddEditSupplierDialog({super.key, this.supplier});

  @override
  State<AddEditSupplierDialog> createState() => _AddEditSupplierDialogState();
}

class _AddEditSupplierDialogState extends State<AddEditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _contactPersonController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.supplier?.phone ?? '',
    );
    _contactPersonController = TextEditingController(
      text: widget.supplier?.contactPerson ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.supplier == null ? l10n.addSupplier : l10n.editSupplier,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.supplierName),
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterNameError : null,
              ),
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(labelText: l10n.contactPerson),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: l10n.phoneLabel),
                keyboardType: TextInputType.phone,
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
          onPressed: _saveSupplier,
          child: Text(l10n.save.toUpperCase()),
        ),
      ],
    );
  }

  void _saveSupplier() {
    if (_formKey.currentState!.validate()) {
      final companion = SuppliersCompanion(
        name: drift.Value(_nameController.text),
        phone: drift.Value(_phoneController.text),
        contactPerson: drift.Value(_contactPersonController.text),
        syncStatus: const drift.Value(1), // Pending sync
      );
      Navigator.pop(context, companion);
    }
  }
}
