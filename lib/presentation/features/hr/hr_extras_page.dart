import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:intl/intl.dart' as intl;

class HRExtrasPage extends StatefulWidget {
  const HRExtrasPage({super.key});

  @override
  State<HRExtrasPage> createState() => _HRExtrasPageState();
}

class _HRExtrasPageState extends State<HRExtrasPage> {
  HREmployee? _selectedEmployee;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final hrService = Provider.of<HRService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('السلف والخصومات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                FutureBuilder<List<HREmployee>>(
                  future: db.select(db.hREmployees).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    return DropdownButtonFormField<HREmployee>(
                      value: _selectedEmployee,
                      decoration: const InputDecoration(labelText: 'الموظف', border: OutlineInputBorder()),
                      items: snapshot.data!.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                      onChanged: (v) => setState(() => _selectedEmployee = v),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (_selectedEmployee == null || _amountController.text.isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await hrService.recordAdvance(
                        employeeId: _selectedEmployee!.id,
                        amount: double.parse(_amountController.text),
                        note: _noteController.text,
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(const SnackBar(content: Text('تم تسجيل العملية بنجاح')));
                      _amountController.clear();
                      _noteController.clear();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  },
                  child: const Text('تسجيل سلفة / خصم'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<HRAdditionalDeduction>>(
              stream: db.select(db.hRAdditionalDeductions).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text('موظف ID: ${item.employeeId} - المبلغ: ${item.amount}'),
                      subtitle: Text('${intl.DateFormat('yyyy-MM-dd').format(item.deductionDate)} - ${item.description ?? ""}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
