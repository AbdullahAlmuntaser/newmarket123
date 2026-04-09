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
  late TextEditingController _taxNumberController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  String _customerType = 'RETAIL';

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
    _taxNumberController = TextEditingController(text: widget.customer?.taxNumber ?? '');
    _addressController = TextEditingController(text: widget.customer?.address ?? '');
    _emailController = TextEditingController(text: widget.customer?.email ?? '');
    _customerType = widget.customer?.customerType ?? 'RETAIL';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _creditLimitController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.customer == null ? l10n.addCustomer : l10n.editCustomer,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: _nameController,
                label: l10n.customerName,
                icon: Icons.person,
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterNameError : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _phoneController,
                label: l10n.phoneLabel,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _taxNumberController,
                label: "الرقم الضريبي (VAT No.)",
                icon: Icons.confirmation_number,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emailController,
                label: "البريد الإلكتروني",
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addressController,
                label: "العنوان",
                icon: Icons.location_on,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _creditLimitController,
                label: l10n.creditLimitLabel,
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _customerType,
                decoration: InputDecoration(
                  labelText: "نوع العميل",
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'RETAIL', child: Text("تجزئة")),
                  DropdownMenuItem(value: 'WHOLESALE', child: Text("جملة")),
                  DropdownMenuItem(value: 'VIP', child: Text("VIP")),
                ],
                onChanged: (value) {
                  setState(() {
                    _customerType = value!;
                  });
                },
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
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _saveCustomer,
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
    int maxLines = 1,
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
      maxLines: maxLines,
    );
  }

  void _saveCustomer() {
    if (_formKey.currentState!.validate()) {
      final companion = CustomersCompanion(
        name: drift.Value(_nameController.text),
        phone: drift.Value(_phoneController.text),
        taxNumber: drift.Value(_taxNumberController.text),
        address: drift.Value(_addressController.text),
        email: drift.Value(_emailController.text),
        customerType: drift.Value(_customerType),
        creditLimit: drift.Value(
          double.tryParse(_creditLimitController.text) ?? 0.0,
        ),
        isActive: const drift.Value(true),
        syncStatus: const drift.Value(1),
      );
      Navigator.pop(context, companion);
    }
  }
}
