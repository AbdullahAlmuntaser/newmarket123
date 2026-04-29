import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
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
    final db = context.watch<AppDatabase>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('قيد يومية يدوي'), elevation: 0),
      body: StreamBuilder<List<GLAccount>>(
        stream: provider.watchAccounts(),
        builder: (context, accSnapshot) {
          return StreamBuilder<List<CostCenter>>(
            stream: db.select(db.costCenters).watch(),
            builder: (context, ccSnapshot) {
              final accounts = (accSnapshot.data ?? []).where((a) => !a.isHeader).toList();
              final costCenters = ccSnapshot.data ?? [];
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildHeader(colorScheme),
                    const SizedBox(height: 16),
                    ..._lines.asMap().entries.map(
                      (entry) => _buildLineCard(entry.key, entry.value, accounts, costCenters, colorScheme),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _lines.add(ManualLine())),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة حساب للقيد'),
                    ),
                    const SizedBox(height: 150),
                  ],
                ),
              );
            },
          );
        },
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

  Widget _buildLineCard(
    int index,
    ManualLine line,
    List<GLAccount> accounts,
    List<CostCenter> costCenters,
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
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: line.accountId,
                    decoration: const InputDecoration(labelText: 'الحساب', isDense: true),
                    items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.code} - ${a.name}'))).toList(),
                    onChanged: (val) => setState(() => line.accountId = val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: line.costCenterId,
                    decoration: const InputDecoration(labelText: 'مركز التكلفة', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('بدون مركز')),
                      ...costCenters.map((cc) => DropdownMenuItem(value: cc.id, child: Text(cc.name))),
                    ],
                    onChanged: (val) => setState(() => line.costCenterId = val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _lines.removeAt(index)),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'مدين'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() => line.debit = double.tryParse(val) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'دائن'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() => line.credit = double.tryParse(val) ?? 0),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('المدين: $_totalDebit'),
              Text('الدائن: $_totalCredit'),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBalanced ? () => _saveEntry(provider) : null,
              child: Text(_isBalanced ? 'حفظ وترحيل' : 'القيد غير متزن'),
            ),
          ),
        ],
      ),
    );
  }

  void _saveEntry(AccountingProvider provider) async {
    final lines = _lines
        .where((l) => l.accountId != null)
        .map((l) => GLLinesCompanion.insert(
              entryId: '',
              accountId: l.accountId!,
              costCenterId: drift.Value(l.costCenterId),
              debit: drift.Value(l.debit),
              credit: drift.Value(l.credit),
            ))
        .toList();
    await provider.createManualEntry(
      description: _descriptionController.text,
      date: _selectedDate,
      lines: lines,
    );
    if(mounted) Navigator.pop(context);
  }
}

class ManualLine {
  String? accountId;
  String? costCenterId;
  double debit = 0;
  double credit = 0;
}
