import 'package:flutter/material.dart';

class MoneyFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final bool required;
  final bool allowZero;
  final bool allowNegative;
  final bool enabled;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<double>? onValidChanged;
  final InputDecoration? decoration;
  final AutovalidateMode autovalidateMode;

  const MoneyFormField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.required = false,
    this.allowZero = true,
    this.allowNegative = false,
    this.enabled = true,
    this.helperText,
    this.onChanged,
    this.onValidChanged,
    this.decoration,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : assert(controller == null || initialValue == null,
            'Use either controller or initialValue, not both.');

  static double? tryParse(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static double valueOf(TextEditingController controller) =>
      tryParse(controller.text) ?? 0.0;

  static String? validateMoney(
    String? value,
    String label, {
    bool required = false,
    bool allowZero = true,
    bool allowNegative = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? '$label مطلوب' : null;

    final parsed = double.tryParse(text);
    if (parsed == null) return 'أدخل رقمًا صحيحًا في $label';
    if (!allowNegative && parsed < 0) return '$label لا يمكن أن يكون سالبًا';
    if (!allowZero && parsed == 0) return '$label يجب أن يكون أكبر من صفر';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: decoration ??
          InputDecoration(
            labelText: label,
            helperText: helperText,
            border: const OutlineInputBorder(),
          ),
      autovalidateMode: autovalidateMode,
      validator: (value) => validateMoney(
        value,
        label,
        required: required,
        allowZero: allowZero,
        allowNegative: allowNegative,
      ),
      onChanged: (value) {
        onChanged?.call(value);
        final parsed = tryParse(value);
        if (parsed == null) return;
        if (!allowNegative && parsed < 0) return;
        if (!allowZero && parsed == 0) return;
        onValidChanged?.call(parsed);
      },
    );
  }
}

class QuantityFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final bool required;
  final bool allowZero;
  final bool allowNegative;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<double>? onValidChanged;
  final InputDecoration? decoration;
  final AutovalidateMode autovalidateMode;

  const QuantityFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.label = 'الكمية',
    this.required = true,
    this.allowZero = false,
    this.allowNegative = false,
    this.enabled = true,
    this.onChanged,
    this.onValidChanged,
    this.decoration,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : assert(controller == null || initialValue == null,
            'Use either controller or initialValue, not both.');

  static double? tryParse(String? value) => MoneyFormField.tryParse(value);

  @override
  Widget build(BuildContext context) {
    return MoneyFormField(
      controller: controller,
      initialValue: initialValue,
      label: label,
      required: required,
      allowZero: allowZero,
      allowNegative: allowNegative,
      enabled: enabled,
      decoration: decoration ??
          InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      onValidChanged: onValidChanged,
    );
  }
}
