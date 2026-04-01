import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';

class ManualJournalEntryPage extends StatefulWidget {
  const ManualJournalEntryPage({super.key});

  @override
  State<ManualJournalEntryPage> createState() => _ManualJournalEntryPageState();
}

class _ManualJournalEntryPageState extends State<ManualJournalEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final List<JournalLineData> _lines = [];

  @override
  void initState() {
    super.initState();
    _addLine();
    _addLine();
  }

  void _addLine() {
    setState(() {
      _lines.add(JournalLineData());
    });
  }

  void _removeLine(int index) {
    if (_lines.length > 2) {
      setState(() {
        _lines[index].dispose();
        _lines.removeAt(index);
      });
    }
  }

  void _autoBalance(int index) {
    final diff = _totalDebit - _totalCredit;
    setState(() {
      if (diff > 0) {
        _lines[index].creditController.text = diff.abs().toStringAsFixed(2);
        _lines[index].debitController.text = '0.00';
      } else if (diff < 0) {
        _lines[index].debitController.text = diff.abs().toStringAsFixed(2);
        _lines[index].creditController.text = '0.00';
      }
    });
  }

  double get _totalDebit => _lines.fold(
    0.0,
    (sum, item) => sum + (double.tryParse(item.debitController.text) ?? 0.0),
  );
  double get _totalCredit => _lines.fold(
    0.0,
    (sum, item) => sum + (double.tryParse(item.creditController.text) ?? 0.0),
  );
  bool get _isBalanced =>
      (_totalDebit - _totalCredit).abs() < 0.001 && _totalDebit > 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    for (var line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('القيود غير متزنة! يجب أن يتساوى المدين والدائن.'),
        ),
      );
      return;
    }

    final provider = context.read<AccountingProvider>();
    final entry = GLEntriesCompanion.insert(
      description: _descriptionController.text,
      date: Value(_selectedDate),
      referenceType: const Value('Manual'),
    );

    final lines = _lines.map((l) {
      return GLLinesCompanion.insert(
        entryId: '',
        accountId: l.accountId!,
        debit: Value(double.tryParse(l.debitController.text) ?? 0.0),
        credit: Value(double.tryParse(l.creditController.text) ?? 0.0),
        memo: Value(l.memoController.text),
      );
    }).toList();

    try {
      await provider.db.accountingDao.createEntry(entry, lines);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ القيد اليدوي بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('قيد يومية يدوي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: _submit,
            tooltip: 'حفظ القيد',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(child: _buildLinesList(provider)),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف القيد العام',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'التاريخ: ${intl.DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinesList(AccountingProvider provider) {
    return StreamBuilder<List<GLAccount>>(
      stream: provider.watchAccounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = snapshot.data!.where((a) => !a.isHeader).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _lines.length,
          itemBuilder: (context, index) {
            final line = _lines[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: line.accountId,
                            decoration: const InputDecoration(
                              labelText: 'الحساب',
                              isDense: true,
                            ),
                            items: accounts.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  '${a.code} - ${a.name}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => line.accountId = v),
                            validator: (v) => v == null ? 'مطلوب' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.balance, size: 20),
                          onPressed: () => _autoBalance(index),
                          tooltip: 'موازنة تلقائية',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeLine(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: line.debitController,
                            decoration: const InputDecoration(
                              labelText: 'مدين (Debit)',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              if ((double.tryParse(v) ?? 0) > 0) {
                                line.creditController.text = '0.00';
                              }
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: line.creditController,
                            decoration: const InputDecoration(
                              labelText: 'دائن (Credit)',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              if ((double.tryParse(v) ?? 0) > 0) {
                                line.debitController.text = '0.00';
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTotalColumn('إجمالي مدين', _totalDebit, Colors.blue),
                _buildTotalColumn('إجمالي دائن', _totalCredit, Colors.orange),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isBalanced
                          ? Colors.green.withAlpha(26)
                          : Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _isBalanced
                            ? 'القيد متزن ✅'
                            : 'الفرق: ${(_totalDebit - _totalCredit).abs().toStringAsFixed(2)} ❌',
                        style: TextStyle(
                          color: _isBalanced ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  onPressed: _addLine,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalColumn(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class JournalLineData {
  String? accountId;
  final TextEditingController debitController =
      TextEditingController(text: '0.00');
  final TextEditingController creditController =
      TextEditingController(text: '0.00');
  final TextEditingController memoController = TextEditingController();

  void dispose() {
    debitController.dispose();
    creditController.dispose();
    memoController.dispose();
  }
}
