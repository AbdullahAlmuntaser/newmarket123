import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:supermarket/core/services/accounting_service.dart';

class RevaluationDialog extends StatelessWidget {
  final dynamic invoice; // الفاتورة المرحلة

  const RevaluationDialog({super.key, required this.invoice});

  Future<void> _performRevaluation(BuildContext context, String reason) async {
    final accountingService = GetIt.I<AccountingService>();
    // استدعاء المنطق: يولد قيد تسوية جديد ويسجل في AuditTrail
    await accountingService.createRevaluationEntry(invoice, reason);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("فاتورة مرحلة: لا يمكن التعديل"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("هذه الفاتورة تم اعتمادها. هل تود القيام بإجراء تصحيحي؟"),
          const SizedBox(height: 16),
          ListTile(
            title: const Text("إنشاء قيد إعادة تقييم"),
            leading: const Icon(Icons.calculate),
            onTap: () => _performRevaluation(context, "إعادة تقييم الدفعة"),
          ),
          ListTile(
            title: const Text("إنشاء مرتجع"),
            leading: const Icon(Icons.undo),
            onTap: () {
              // تنفيذ منطق المرتجع
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
