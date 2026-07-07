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
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = size.width < 520 ? size.width * 0.94 : 460.0;
    final maxHeight = size.height * 0.78;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.supplier == null ? l10n.addSupplier : l10n.editSupplier,
      ),
      content: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: dialogWidth, maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: l10n.supplierName,
                  icon: Icons.business,
                  validator: (value) => value == null || value.isEmpty
                      ? l10n.enterNameError
                      : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _contactPersonController,
                  label: l10n.contactPerson,
                  icon: Icons.person,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _phoneController,
                  label: l10n.phoneLabel,
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: keyboardType,
      validator: validator,
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
