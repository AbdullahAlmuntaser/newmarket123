import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:provider/provider.dart';
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
  late TextEditingController _exchangeRateController;
  String _customerType = 'RETAIL';
  String? _selectedCurrencyId;
  List<Currency> _currencies = [];
  Currency? _baseCurrency;

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
    _taxNumberController = TextEditingController(
      text: widget.customer?.taxNumber ?? '',
    );
    _addressController = TextEditingController(
      text: widget.customer?.address ?? '',
    );
    _emailController = TextEditingController(
      text: widget.customer?.email ?? '',
    );
    _customerType = widget.customer?.customerType ?? 'RETAIL';
    _selectedCurrencyId = widget.customer?.currencyId;
    _exchangeRateController = TextEditingController(
      text: widget.customer?.exchangeRate.toString() ?? '1.0',
    );

    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final fetchedCurrencies = await db
        .customSelect('SELECT * FROM currencies')
        .map((row) {
          return Currency.fromJson(row.data);
        })
        .get();
    final baseCurrency = fetchedCurrencies.firstWhere(
      (c) => c.isBase,
      orElse: () => fetchedCurrencies.first,
    );

    setState(() {
      _currencies = fetchedCurrencies;
      _baseCurrency = baseCurrency;
      // Set initial currency and exchange rate if customer is new or existing
      if (widget.customer == null) {
        _selectedCurrencyId = baseCurrency.code;
        _exchangeRateController.text = baseCurrency.exchangeRate.toString();
      } else {
        // Ensure selected currency is in the list and update exchange rate if needed
        if (_selectedCurrencyId != null &&
            _currencies.any((c) => c.code == _selectedCurrencyId)) {
          final selected = _currencies.firstWhere(
            (c) => c.code == _selectedCurrencyId,
          );
          _selectedCurrencyId = selected.code;
          _exchangeRateController.text = selected.exchangeRate.toString();
        } else if (_currencies.isNotEmpty) {
          // Fallback to base currency if selected currency is not found
          _selectedCurrencyId = baseCurrency.code;
          _exchangeRateController.text = baseCurrency.exchangeRate.toString();
        } else {
          // If no currencies are available (should not happen with seed data)
          _selectedCurrencyId = null;
          _exchangeRateController.text = '1.0';
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _creditLimitController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _exchangeRateController.dispose();
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
                initialValue: _selectedCurrencyId,
                decoration: InputDecoration(
                  labelText: "عملة العميل",
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _currencies.map((Currency currency) {
                  return DropdownMenuItem<String>(
                    value: currency.code,
                    child: Text('${currency.name} (${currency.code})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCurrencyId = value;
                    final selectedCurrency = _currencies.firstWhere(
                      (c) => c.code == value,
                      orElse: () =>
                          _baseCurrency ??
                          Currency(
                            id: 'USD',
                            code: 'USD',
                            name: 'US Dollar',
                            exchangeRate: 1.0,
                            isBase: false,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                            syncStatus: 1,
                          ), // Fallback
                    );
                    _exchangeRateController.text = selectedCurrency.exchangeRate
                        .toString();
                  });
                },
                validator: (value) =>
                    value == null ? "الرجاء اختيار عملة" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _exchangeRateController,
                label: "سعر الصرف",
                icon: Icons.swap_horiz,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "الرجاء إدخال سعر الصرف";
                  }
                  if (double.tryParse(value) == null) {
                    return "سعر الصرف غير صالح";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _customerType,
                decoration: InputDecoration(
                  labelText: "نوع العميل",
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
        currencyId: drift.Value(_selectedCurrencyId),
        exchangeRate: drift.Value(
          double.tryParse(_exchangeRateController.text) ?? 1.0,
        ),
      );
      Navigator.pop(context, companion);
    }
  }
}
