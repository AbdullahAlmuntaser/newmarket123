import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';

class ManualJournalEntryPage extends StatefulWidget {
  const ManualJournalEntryPage({super.key});

  @override
  State<ManualJournalEntryPage> createState() => _ManualJournalEntryPageState();
}

class _ManualJournalEntryPageState extends State<ManualJournalEntryPage> {
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final List<ManualLine> _lines = [ManualLine(), ManualLine()];

  double get _totalDebit => _lines.fold(0, (sum, l) => sum + l.debit);
  double get _totalCredit => _lines.fold(0, (sum, l) => sum + l.credit);
  bool get _isBalanced =>
      (_totalDebit - _totalCredit).abs() < 0.001 && _totalDebit > 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('قيد يومية يدوي')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildLinesList(provider),
            const SizedBox(height: 16),
            _buildFooter(),
          ],
        ),
      ),
      bottomNavigationBar: _buildSaveBar(provider),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'وصف القيد'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('التاريخ'),
              trailing: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesList(AccountingProvider provider) {
    return StreamBuilder<List<GLAccount>>(
      stream: provider.watchAccounts(),
      builder: (context, snapshot) {
        final accounts = (snapshot.data ?? [])
            .where((a) => !a.isHeader)
            .toList();
        return Column(
          children: [
            ..._lines.asMap().entries.map(
              (entry) => _buildLineRow(entry.key, entry.value, accounts),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _lines.add(ManualLine())),
              icon: const Icon(Icons.add),
              label: const Text('إضافة سطر'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineRow(int index, ManualLine line, List<GLAccount> accounts) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButton<String>(
                value: line.accountId,
                hint: const Text('اختر الحساب'),
                isExpanded: true,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.code} - ${a.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => line.accountId = val),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'مدين'),
                keyboardType: TextInputType.number,
                onChanged: (val) =>
                    setState(() => line.debit = double.tryParse(val) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'دائن'),
                keyboardType: TextInputType.number,
                onChanged: (val) =>
                    setState(() => line.credit = double.tryParse(val) ?? 0),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => setState(() => _lines.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text('إجمالي المدين'),
              Text(
                _totalDebit.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          Column(
            children: [
              const Text('إجمالي الدائن'),
              Text(
                _totalCredit.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(AccountingProvider provider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PermissionGuard(
          permissionCode: 'accounting.edit_journal',
          child: ElevatedButton(
            onPressed: _isBalanced ? () => _saveEntry(provider) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBalanced ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'حفظ القيد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  void _saveEntry(AccountingProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final lines = _lines
          .where((l) => l.accountId != null)
          .map(
            (l) => GLLinesCompanion.insert(
              entryId: '', // Placeholder, will be updated in provider
              accountId: l.accountId!,
              debit: Value(l.debit),
              credit: Value(l.credit),
            ),
          )
          .toList();

      await provider.createManualEntry(
        description: _descriptionController.text,
        date: _selectedDate,
        lines: lines,
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('تم حفظ القيد بنجاح')),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class ManualLine {
  String? accountId;
  double debit = 0;
  double credit = 0;
}
