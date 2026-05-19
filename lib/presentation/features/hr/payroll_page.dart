import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/hr/payroll_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:supermarket/presentation/widgets/money_form_field.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PayrollProvider>().loadPayrollEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayrollProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('مسيرات الرواتب')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.entries.length,
              itemBuilder: (context, index) {
                final entry = provider.entries[index];
                return ListTile(
                  leading: const Icon(Icons.payments),
                  title: Text('الفترة: ${entry.period}'),
                  subtitle: Text(
                    'الحالة: ${entry.status}',
                  ),
                  onTap: () => _showPayrollDetails(context, provider, entry),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGenerateDialog(context, provider),
        child: const Icon(Icons.add_chart),
      ),
    );
  }

  void _showGenerateDialog(BuildContext context, PayrollProvider provider) {
    final monthController = TextEditingController(
      text: DateTime.now().month.toString(),
    );
    final yearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('توليد مسير رواتب'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            QuantityFormField(
              controller: monthController,
              label: 'الشهر',
              allowZero: false,
              decoration: const InputDecoration(labelText: 'الشهر'),
            ),
            QuantityFormField(
              controller: yearController,
              label: 'السنة',
              allowZero: false,
              decoration: const InputDecoration(labelText: 'السنة'),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                AppSnackBar.warning(context, 'يرجى إدخال شهر وسنة صحيحين');
                return;
              }
              final month = MoneyFormField.tryParse(monthController.text)?.toInt();
              final year = MoneyFormField.tryParse(yearController.text)?.toInt();
              if (month == null || month < 1 || month > 12) {
                AppSnackBar.warning(context, 'الشهر يجب أن يكون بين 1 و12');
                return;
              }
              if (year == null || year < 2000) {
                AppSnackBar.warning(context, 'السنة غير صحيحة');
                return;
              }
              final period = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
              provider.generatePayroll(period);
              Navigator.pop(context);
            },
            child: const Text('توليد'),
          ),
        ],
      ),
    );
  }

  void _showPayrollDetails(
    BuildContext context,
    PayrollProvider provider,
    HRPayrollRun entry,
  ) async {
    final lines = await provider.getPayrollLines(entry.id);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'تفاصيل رواتب الفترة: ${entry.period}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final db = context.read<AppDatabase>();
                  return ListTile(
                    title: FutureBuilder<HREmployee?>(
                      future: (db.select(db.hREmployees)
                            ..where((t) => t.id.equals(line.employeeId)))
                          .getSingleOrNull(),
                      builder: (context, snapshot) =>
                          Text(snapshot.data?.name ?? 'تحميل...'),
                    ),
                    subtitle: Text(
                      'الأساسي: ${line.basicSalary} | البدلات: ${line.housingAllowance + line.transportAllowance + line.otherAllowances} | الخصومات: ${line.deductions}',
                    ),
                    trailing: Text(
                      line.netSalary.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
