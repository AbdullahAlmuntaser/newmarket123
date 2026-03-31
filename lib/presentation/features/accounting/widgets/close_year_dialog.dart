import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';

class CloseFinancialYearDialog extends StatefulWidget {
  const CloseFinancialYearDialog({super.key});

  @override
  State<CloseFinancialYearDialog> createState() =>
      _CloseFinancialYearDialogState();
}

class _CloseFinancialYearDialogState extends State<CloseFinancialYearDialog> {
  DateTime _selectedDate = DateTime.now();
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إغلاق السنة المالية'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'سيتم ترحيل جميع أرصدة الإيرادات والمصاريف إلى حساب الأرباح المحتجزة، وتصفير الحسابات المؤقتة للسنة الجديدة.',
            style: TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: Text(
              'تاريخ الإغلاق: ${_selectedDate.toLocal().toString().split(' ')[0]}',
            ),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isClosing ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: _isClosing
              ? null
              : () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final provider = context.read<AccountingProvider>();

                  setState(() => _isClosing = true);
                  try {
                    await provider.closeYear(_selectedDate);
                    if (mounted) {
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('تم إغلاق السنة المالية بنجاح'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('فشل الإغلاق: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isClosing = false);
                  }
                },
          child: _isClosing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تأكيد الإغلاق'),
        ),
      ],
    );
  }
}
