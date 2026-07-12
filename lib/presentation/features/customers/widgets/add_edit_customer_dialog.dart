import 'dart:developer' as developer;

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
  bool _isLoadingCurrencies = true;
  String? _currencyLoadError;

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
    try {
      if (mounted) {
        setState(() {
          _isLoadingCurrencies = true;
          _currencyLoadError = null;
        });
      }

      await db.ensureDefaultCurrencies();
      final fetchedCurrencies = await (db.select(db.currencies)
            ..orderBy([(c) => drift.OrderingTerm.asc(c.code)]))
          .get();

      if (fetchedCurrencies.isEmpty) {
        throw Exception('لم يتم العثور على أي عملات بعد التهيئة.');
      }

      final baseCurrency = fetchedCurrencies.firstWhere(
        (c) => c.isBase,
        orElse: () => fetchedCurrencies.first,
      );

      if (!mounted) return;
      setState(() {
        _currencies = fetchedCurrencies;
        _baseCurrency = baseCurrency;
        _isLoadingCurrencies = false;

        final requestedCurrency = _selectedCurrencyId;
        final selectedCurrency = requestedCurrency != null
            ? _currencies.cast<Currency?>().firstWhere(
                  (c) =>
                      c?.code == requestedCurrency ||
                      c?.id == requestedCurrency,
                  orElse: () => null,
                )
            : null;
        final effectiveCurrency = selectedCurrency ?? baseCurrency;
        _selectedCurrencyId = effectiveCurrency.id;
        _exchangeRateController.text =
            effectiveCurrency.exchangeRate.toString();
      });
    } catch (e, st) {
      developer.log(
        'Failed to load customer currencies',
        name: 'customers.currency',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _currencies = [];
        _baseCurrency = null;
        _selectedCurrencyId = null;
        _isLoadingCurrencies = false;
        _currencyLoadError =
            'تعذر تحميل العملات. يرجى إعادة المحاولة أو تهيئة بيانات النظام.';
      });
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final dialogWidth = size.width < 560 ? size.width * 0.94 : 520.0;
        final maxHeight = size.height * 0.82;

        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(
            widget.customer == null ? l10n.addCustomer : l10n.editCustomer,
            style: const TextStyle(fontWeight: FontWeight.bold),
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
                      label: l10n.customerName,
                      icon: Icons.person,
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.enterNameError
                          : null,
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
                    _buildCurrencyField(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _exchangeRateController,
                      label: "سعر الصرف",
                      icon: Icons.swap_horiz,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                      value: _customerType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "نوع العميل",
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'RETAIL', child: Text("تجزئة")),
                        DropdownMenuItem(
                            value: 'WHOLESALE', child: Text("جملة")),
                        DropdownMenuItem(value: 'VIP', child: Text("VIP")),
                      ],
                      onChanged: (value) =>
                          setState(() => _customerType = value!),
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
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _isLoadingCurrencies || _currencyLoadError != null
                  ? null
                  : _saveCustomer,
              child: Text(l10n.save.toUpperCase()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrencyField() {
    if (_isLoadingCurrencies) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('جاري تحميل العملات...'),
      );
    }

    if (_currencyLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_currencyLoadError!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadCurrencies,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة تحميل العملات'),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedCurrencyId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: "عملة العميل",
        prefixIcon: const Icon(Icons.attach_money),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _currencies.map((Currency currency) {
        return DropdownMenuItem<String>(
          value: currency.id,
          child: Text('${currency.name} (${currency.code})',
              overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: _currencies.isEmpty
          ? null
          : (value) {
              setState(() {
                _selectedCurrencyId = value;
                final selectedCurrency = _currencies.firstWhere(
                  (c) => c.id == value,
                  orElse: () => _baseCurrency ?? _currencies.first,
                );
                _exchangeRateController.text =
                    selectedCurrency.exchangeRate.toString();
              });
            },
      validator: (value) {
        if (_currencies.isEmpty) {
          return 'لا توجد عملات متاحة. يرجى تهيئة بيانات النظام.';
        }
        return value == null ? "الرجاء اختيار عملة" : null;
      },
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
          Decimal.tryParse(_creditLimitController.text) ?? Decimal.zero,
        ),
        isActive: const drift.Value(true),
        syncStatus: const drift.Value(1),
        currencyId: drift.Value(_selectedCurrencyId),
        exchangeRate: drift.Value(
          Decimal.tryParse(_exchangeRateController.text) ?? Decimal.one,
        ),
      );
      Navigator.pop(context, companion);
    }
  }
}
