import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/hr/payroll_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

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
                  title: Text('شهر ${entry.month} - سنة ${entry.year}'),
                  subtitle: Text('الحالة: ${entry.status} - ${entry.note ?? ''}'),
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
    final monthController = TextEditingController(text: DateTime.now().month.toString());
    final yearController = TextEditingController(text: DateTime.now().year.toString());
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('توليد مسير رواتب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: monthController, decoration: const InputDecoration(labelText: 'الشهر'), keyboardType: TextInputType.number),
            TextField(controller: yearController, decoration: const InputDecoration(labelText: 'السنة'), keyboardType: TextInputType.number),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'ملاحظات')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              provider.generatePayroll(
                int.tryParse(monthController.text) ?? 1,
                int.tryParse(yearController.text) ?? 2024,
                note: noteController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('توليد'),
          ),
        ],
      ),
    );
  }

  void _showPayrollDetails(BuildContext context, PayrollProvider provider, PayrollEntry entry) async {
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
              child: Text('تفاصيل رواتب شهر ${entry.month}/${entry.year}', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final db = context.read<AppDatabase>();
                  return ListTile(
                    title: FutureBuilder<Employee?>(
                      future: (db.select(db.employees)..where((t) => t.id.equals(line.employeeId))).getSingleOrNull(),
                      builder: (context, snapshot) => Text(snapshot.data?.name ?? 'تحميل...'),
                    ),
                    subtitle: Text('الأساسي: ${line.basicSalary} | البدلات: ${line.allowances} | الخصومات: ${line.deductions}'),
                    trailing: Text(line.netSalary.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
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
