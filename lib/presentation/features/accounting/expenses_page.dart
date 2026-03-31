import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart' as dao;
import 'package:supermarket/domain/entities/account.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.expenses)),
      body: StreamBuilder<List<GLEntry>>(
        stream: db.accountingDao.watchRecentEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries =
              snapshot.data
                  ?.where((e) => e.referenceType == 'EXPENSE')
                  .toList() ??
              [];

          if (entries.isEmpty) {
            return Center(child: Text(l10n.noSalesFound));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return FutureBuilder<List<dao.GLLineWithAccount>>(
                future: db.accountingDao.getLinesForEntry(entry.id),
                builder: (context, lineSnapshot) {
                  final lines = lineSnapshot.data ?? [];
                  final expenseLine = lines.isEmpty
                      ? null
                      : lines.cast<dao.GLLineWithAccount?>().firstWhere(
                          (l) => l != null && l.line.debit > 0,
                          orElse: () => null,
                        );
                  return ListTile(
                    title: Text(entry.description),
                    subtitle: Text(entry.date.toString().split(' ')[0]),
                    trailing: Text(
                      expenseLine?.line.debit.toStringAsFixed(2) ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();
    final accountingService = AccountingService(db);

    final allAccounts = await db.accountingDao.getAllAccounts();
    final expenseAccounts = allAccounts
        .where((a) => a.type == AccountType.expense.toString())
        .toList();
    final paymentAccounts = allAccounts
        .where(
          (a) =>
              a.type == AccountType.asset.toString() &&
              (a.code == AccountingService.codeCash ||
                  a.code == AccountingService.codeBank),
        )
        .toList();

    if (!mounted) return;

    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    GLAccount? selectedExpenseAccount;
    GLAccount? selectedPaymentAccount = paymentAccounts.isNotEmpty
        ? paymentAccounts.first
        : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.expenses),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: l10n.overview),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.total),
                ),
                DropdownButtonFormField<GLAccount>(
                  initialValue: selectedExpenseAccount,
                  items: expenseAccounts
                      .map(
                        (a) => DropdownMenuItem(value: a, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedExpenseAccount = val),
                  decoration: InputDecoration(labelText: l10n.accountType),
                ),
                DropdownButtonFormField<GLAccount>(
                  initialValue: selectedPaymentAccount,
                  items: paymentAccounts
                      .map(
                        (a) => DropdownMenuItem(value: a, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedPaymentAccount = val),
                  decoration: InputDecoration(labelText: l10n.cashPayment),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descriptionController.text.isNotEmpty &&
                  amountController.text.isNotEmpty &&
                  selectedExpenseAccount != null &&
                  selectedPaymentAccount != null) {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                await accountingService.recordExpense(
                  description: descriptionController.text,
                  amount: amount,
                  date: DateTime.now(),
                  expenseAccountId: selectedExpenseAccount!.id.toString(),
                  paymentAccountId: selectedPaymentAccount!.id.toString(),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
