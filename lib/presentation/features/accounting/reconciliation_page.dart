import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class ReconciliationPage extends StatefulWidget {
  const ReconciliationPage({super.key});

  @override
  State<ReconciliationPage> createState() => _ReconciliationPageState();
}

class _ReconciliationPageState extends State<ReconciliationPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedAccountId;
  double _bookBalance = 0.0;
  final _actualBalanceController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _actualBalanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onAccountChanged(String? accountId) async {
    if (accountId == null) return;
    setState(() {
      _selectedAccountId = accountId;
      _isLoading = true;
    });

    final provider = context.read<AccountingProvider>();
    final balance = await provider.db.accountingDao.getAccountBalance(
      accountId,
    );

    setState(() {
      _bookBalance = balance;
      _isLoading = false;
    });
  }

  double get _actualBalance =>
      double.tryParse(_actualBalanceController.text) ?? 0.0;
  double get _difference => _actualBalance - _bookBalance;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<AccountingProvider>();
    final l10n = AppLocalizations.of(context)!;

    try {
      await provider.db.transaction(() async {
        // 1. Create reconciliation record
        await provider.db.accountingDao.createReconciliation(
          ReconciliationsCompanion.insert(
            accountId: _selectedAccountId!,
            bookBalance: _bookBalance,
            actualBalance: _actualBalance,
            difference: _difference,
            note: Value(_noteController.text),
            date: Value(DateTime.now()),
          ),
        );

        // 2. Create an adjustment journal entry if difference != 0
        if (_difference != 0) {
          final overShortAccount = await provider.db.accountingDao
              .getAccountByCode(AccountingService.codeCashOverShort);

          if (overShortAccount == null) {
            throw Exception(
              'Cash Over/Short account not found. Please seed accounts.',
            );
          }

          final entryId = const Uuid().v4();
          await provider.db.accountingDao.createEntry(
            GLEntriesCompanion.insert(
              id: Value(entryId),
              description:
                  '${l10n.reconciliationAdjustment}: ${_noteController.text}',
              date: Value(DateTime.now()),
              referenceType: const Value('RECONCILIATION'),
            ),
            [
              // Line 1: The Cash/Bank Account
              GLLinesCompanion.insert(
                entryId: entryId,
                accountId: _selectedAccountId!,
                debit: Value(_difference > 0 ? _difference : 0.0),
                credit: Value(_difference < 0 ? _difference.abs() : 0.0),
                memo: Value(l10n.reconciliationAdjustment),
              ),
              // Line 2: Cash Over/Short Account
              GLLinesCompanion.insert(
                entryId: entryId,
                accountId: overShortAccount.id,
                debit: Value(_difference < 0 ? _difference.abs() : 0.0),
                credit: Value(_difference > 0 ? _difference : 0.0),
                memo: Value(l10n.reconciliationAdjustment),
              ),
            ],
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.saveSuccess)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reconciliation)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StreamBuilder<List<GLAccount>>(
                      stream: provider.watchAccounts(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        // Filter for Bank and Cash accounts (ASSET type)
                        final accounts = snapshot.data!
                            .where((a) => !a.isHeader && a.type == 'asset')
                            .toList();

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedAccountId,
                          decoration: InputDecoration(
                            labelText: l10n.selectAccount,
                            border: const OutlineInputBorder(),
                          ),
                          items: accounts.map((a) {
                            return DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.code} - ${a.name}'),
                            );
                          }).toList(),
                          onChanged: _onAccountChanged,
                          validator: (value) =>
                              value == null ? l10n.selectAccountError : null,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildBalanceRow(
                              l10n.bookBalance,
                              _bookBalance,
                              Colors.blue,
                            ),
                            const Divider(height: 32),
                            TextFormField(
                              controller: _actualBalanceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: l10n.actualBalance,
                                prefixIcon: const Icon(
                                  Icons.account_balance_wallet,
                                ),
                                border: const OutlineInputBorder(),
                                hintText: '0.00',
                              ),
                              onChanged: (v) => setState(() {}),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.enterActualBalanceError;
                                }
                                if (double.tryParse(value) == null) {
                                  return l10n.enterAmountError;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            _buildBalanceRow(
                              l10n.reconciliationDifference,
                              _difference,
                              _difference == 0
                                  ? Colors.green
                                  : (_difference < 0
                                        ? Colors.red
                                        : Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: l10n.notes,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _selectedAccountId == null ? null : _submit,
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        l10n.save,
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
