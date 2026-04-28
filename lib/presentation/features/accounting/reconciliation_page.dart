import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class ReconciliationPage extends StatefulWidget {
  const ReconciliationPage({super.key});

  @override
  State<ReconciliationPage> createState() => _ReconciliationPageState();
}

class _ReconciliationPageState extends State<ReconciliationPage> {
  String? _selectedAccountId;
  final _actualBalanceController = TextEditingController();
  final _noteController = TextEditingController();
  double _bookBalance = 0.0;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('تسوية الأرصدة (صندوق/بنك)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAccountSelector(db),
            const SizedBox(height: 20),
            if (_selectedAccountId != null) ...[
              _buildBalanceComparison(),
              const SizedBox(height: 20),
              TextField(
                controller: _actualBalanceController,
                decoration: const InputDecoration(
                  labelText: 'الرصيد الفعلي (الموجود حالياً)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات التسوية',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              _buildSubmitButton(db),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSelector(AppDatabase db) {
    return StreamBuilder<List<GLAccount>>(
      stream:
          (db.select(db.gLAccounts)..where(
                (t) =>
                    t.code.equals(AccountingService.codeCash) |
                    t.code.equals(AccountingService.codeBank),
              ))
              .watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedAccountId,
          decoration: const InputDecoration(
            labelText: 'اختر الحساب المراد تسويته',
          ),
          items: snapshot.data!
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (val) async {
            if (val != null) {
              final balance = await db.accountingDao.getAccountBalance(val);
              setState(() {
                _selectedAccountId = val;
                _bookBalance = balance;
              });
            }
          },
        );
      },
    );
  }

  Widget _buildBalanceComparison() {
    final actual = double.tryParse(_actualBalanceController.text) ?? 0.0;
    final diff = actual - _bookBalance;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _row('الرصيد الدفتري (في النظام):', _bookBalance.toStringAsFixed(2)),
          const Divider(),
          _row(
            'الفارق:',
            diff.toStringAsFixed(2),
            color: diff < 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AppDatabase db) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () async {
          final actual = double.tryParse(_actualBalanceController.text) ?? 0.0;
          final diff = actual - _bookBalance;

          if (diff == 0) {
            // No difference, just record reconciliation
            await db
                .into(db.reconciliations)
                .insert(
                  ReconciliationsCompanion.insert(
                    accountId: _selectedAccountId!,
                    bookBalance: _bookBalance,
                    actualBalance: actual,
                    difference: diff,
                    note: drift.Value(_noteController.text),
                  ),
                );
          } else {
            // Create journal entry for the difference
            final cashAccount = await db.accountingDao.getAccountByCode(
              AccountingService.codeCash,
            );
            final cashOverShort = await db.accountingDao.getAccountByCode(
              AccountingService.codeCashOverShort,
            );

            if (cashAccount == null || cashOverShort == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'حساب الصندوق أو حساب العجز/الزيادة غير موجود',
                    ),
                  ),
                );
              }
              return;
            }

            final entryId = const Uuid().v4();
            final absDiff = diff.abs();

            final entry = GLEntriesCompanion.insert(
              id: drift.Value(entryId),
              description:
                  'تسوية: ${_noteController.text.isEmpty ? 'فرق تسوية' : _noteController.text}',
              date: drift.Value(DateTime.now()),
              referenceType: const drift.Value('RECONCILIATION'),
              referenceId: drift.Value(entryId),
              status: const drift.Value('POSTED'),
              postedAt: drift.Value(DateTime.now()),
            );

            final lines = diff > 0
                ? // Actual > Book: Cash increased (extra cash found)
                  [
                    GLLinesCompanion.insert(
                      entryId: entryId,
                      accountId: cashAccount.id,
                      debit: drift.Value(absDiff),
                      credit: const drift.Value(0.0),
                    ),
                    GLLinesCompanion.insert(
                      entryId: entryId,
                      accountId: cashOverShort.id,
                      debit: const drift.Value(0.0),
                      credit: drift.Value(absDiff),
                    ),
                  ]
                : // Actual < Book: Cash decreased (shortage)
                  [
                    GLLinesCompanion.insert(
                      entryId: entryId,
                      accountId: cashOverShort.id,
                      debit: drift.Value(absDiff),
                      credit: const drift.Value(0.0),
                    ),
                    GLLinesCompanion.insert(
                      entryId: entryId,
                      accountId: cashAccount.id,
                      debit: const drift.Value(0.0),
                      credit: drift.Value(absDiff),
                    ),
                  ];

            await db.accountingDao.createEntry(entry, lines);

            // Record reconciliation
            await db
                .into(db.reconciliations)
                .insert(
                  ReconciliationsCompanion.insert(
                    accountId: _selectedAccountId!,
                    bookBalance: _bookBalance,
                    actualBalance: actual,
                    difference: diff,
                    note: drift.Value(_noteController.text),
                  ),
                );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تسجيل التسوية بنجاح')),
            );
            _actualBalanceController.clear();
            _noteController.clear();
            setState(() => _bookBalance = 0.0);
          }
        },
        child: const Text('تأكيد وتسجيل التسوية'),
      ),
    );
  }
}
