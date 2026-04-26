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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('قيد يومية يدوي'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildHeader(colorScheme),
            const SizedBox(height: 16),
            _buildLinesList(provider, colorScheme),
            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
      bottomSheet: _buildPersistentFooter(provider),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'وصف القيد العام',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ القيد',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesList(AccountingProvider provider, ColorScheme colorScheme) {
    return StreamBuilder<List<GLAccount>>(
      stream: provider.watchAccounts(),
      builder: (context, snapshot) {
        final accounts = (snapshot.data ?? [])
            .where((a) => !a.isHeader)
            .toList();
        return Column(
          children: [
            ..._lines.asMap().entries.map(
              (entry) =>
                  _buildLineCard(entry.key, entry.value, accounts, colorScheme),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => setState(() => _lines.add(ManualLine())),
              icon: const Icon(Icons.add),
              label: const Text('إضافة حساب للقيد'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineCard(
    int index,
    ManualLine line,
    List<GLAccount> accounts,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.accountId,
                    decoration: const InputDecoration(
                      labelText: 'الحساب',
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              '${a.code} - ${a.name}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => line.accountId = val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _lines.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'مدين (Debit)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) =>
                        setState(() => line.debit = double.tryParse(val) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'دائن (Credit)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) =>
                        setState(() => line.credit = double.tryParse(val) ?? 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentFooter(AccountingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('إجمالي المدين', _totalDebit, Colors.green),
              const VerticalDivider(),
              _summaryItem('إجمالي الدائن', _totalCredit, Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PermissionGuard(
              permission: 'accounting.edit_journal',
              child: ElevatedButton(
                onPressed: _isBalanced ? () => _saveEntry(provider) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBalanced
                      ? Colors.green
                      : Colors.grey.shade300,
                  foregroundColor: _isBalanced
                      ? Colors.white
                      : Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isBalanced ? 'حفظ وترحيل القيد' : 'القيد غير متزن',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          val.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
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
              entryId: '',
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
